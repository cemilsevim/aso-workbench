#!/usr/bin/env bash
# Turns a screen recording into the README demo:
#   docs/media/demo.mp4  H.264, ≤1920×1080, plays in every browser (GitHub, README link)
#   docs/media/demo.gif  short, silent preview that autoplays at the top of the README
#   docs/media/demo-poster.png  first frame, for places that cannot show the gif
#
#   scripts/make-demo.sh "/path/to/Screen Recording.mov" [gif-seconds=20] [gif-width=960] [gif-fps=8]
#
# Needs only macOS tools (swift / AVFoundation) and Python 3 with Pillow for the gif (pip3 install pillow).
set -euo pipefail
SRC="${1:?usage: scripts/make-demo.sh recording.mov [gif-seconds] [gif-width] [gif-fps]}"
SECS="${2:-20}"; WIDTH="${3:-960}"; FPS="${4:-8}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/media"; mkdir -p "$OUT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# 1. mp4 — H.264 at a bitrate that suits screen recordings (mostly still text), so a minute stays under ~10 MB.
#    Only video and sound are copied; location, device and other metadata of the recording are not.
cat > "$TMP/encode.swift" <<'SWIFT'
import AVFoundation
let a = CommandLine.arguments
let src = AVURLAsset(url: URL(fileURLWithPath: a[1])), out = URL(fileURLWithPath: a[2])
let maxWidth = Double(a[3])!, maxBitrate = Double(a[4])!, targetBytes = Double(a[5])!
try? FileManager.default.removeItem(at: out)
let sema = DispatchSemaphore(value: 0)
Task {
    let vTrack = try await src.loadTracks(withMediaType: .video).first!
    let natural = try await vTrack.load(.naturalSize), transform = try await vTrack.load(.preferredTransform)
    let size = natural.applying(transform)
    let w0 = abs(size.width), h0 = abs(size.height)
    let scale = min(1, maxWidth / w0)
    let w = Int((w0 * scale / 2).rounded()) * 2, h = Int((h0 * scale / 2).rounded()) * 2
    // Stay under the target size (GitHub plays uploaded videos up to 10 MB on free accounts): bitrate from duration.
    let seconds = max(1, CMTimeGetSeconds(try await src.load(.duration)))
    let bitrate = Int(min(maxBitrate, (targetBytes * 8 * 0.92) / seconds - 64_000))
    let reader = try AVAssetReader(asset: src)
    let vOut = AVAssetReaderVideoCompositionOutput(videoTracks: [vTrack], videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    let comp = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: src)
    comp.renderSize = CGSize(width: w, height: h)
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
    layer.setTransform(transform.concatenating(CGAffineTransform(scaleX: scale, y: scale)), at: .zero)
    let ins = AVMutableVideoCompositionInstruction()
    ins.timeRange = CMTimeRange(start: .zero, duration: try await src.load(.duration))
    ins.layerInstructions = [layer]
    comp.instructions = [ins]
    vOut.videoComposition = comp
    reader.add(vOut)
    let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate, AVVideoMaxKeyFrameIntervalDurationKey: 4,
                                          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
    vIn.expectsMediaDataInRealTime = false
    writer.add(vIn)
    var aOut: AVAssetReaderTrackOutput?, aIn: AVAssetWriterInput?
    if let aTrack = try await src.loadTracks(withMediaType: .audio).first {
        let o = AVAssetReaderTrackOutput(track: aTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
        reader.add(o); aOut = o
        let i = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44_100, AVEncoderBitRateKey: 64_000])
        i.expectsMediaDataInRealTime = false
        writer.add(i); aIn = i
    }
    reader.startReading(); writer.startWriting(); writer.startSession(atSourceTime: .zero)
    func pump(_ input: AVAssetWriterInput, _ output: AVAssetReaderOutput, _ q: DispatchQueue) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            input.requestMediaDataWhenReady(on: q) {
                while input.isReadyForMoreMediaData {
                    if let b = output.copyNextSampleBuffer() { input.append(b) } else { input.markAsFinished(); c.resume(); return }
                }
            }
        }
    }
    async let v: Void = pump(vIn, vOut, DispatchQueue(label: "v"))
    if let aIn, let aOut { await pump(aIn, aOut, DispatchQueue(label: "a")) }
    await v
    await writer.finishWriting()
    if writer.status != .completed { print("encode failed: \(writer.error?.localizedDescription ?? "?")"); exit(1) }
    sema.signal()
}
sema.wait()
SWIFT
swift "$TMP/encode.swift" "$SRC" "$OUT/demo.mp4" 1600 1500000 9500000 2>/dev/null

# 2. frames for the gif
cat > "$TMP/frames.swift" <<'SWIFT'
import AVFoundation
import AppKit
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let seconds = Double(a[2])!, width = Double(a[3])!, fps = Double(a[4])!, dir = a[5]
let duration = CMTimeGetSeconds(asset.duration)
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.maximumSize = CGSize(width: width, height: width * 4)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
let count = Int(min(seconds, duration) * fps)
for i in 0..<count {
    let t = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)
    guard let cg = try? gen.copyCGImage(at: t, actualTime: nil) else { continue }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: String(format: "%@/f%05d.png", dir, i)))
}
print(String(format: "%.1f", duration))
SWIFT
DURATION="$(swift "$TMP/frames.swift" "$SRC" "$SECS" "$WIDTH" "$FPS" "$TMP")"
cp "$TMP/f00000.png" "$OUT/demo-poster.png"

# 3. gif — one shared palette keeps it small and flicker-free
python3 - "$TMP" "$OUT/demo.gif" "$FPS" <<'PY'
import sys, glob
from PIL import Image
tmp, out, fps = sys.argv[1], sys.argv[2], float(sys.argv[3])
frames = [Image.open(p).convert("RGB") for p in sorted(glob.glob(f"{tmp}/f*.png"))]
sheet = Image.new("RGB", (frames[0].width, frames[0].height * min(len(frames), 12)))
for i, f in enumerate(frames[:: max(1, len(frames) // 12)][:12]): sheet.paste(f, (0, i * frames[0].height))
palette = sheet.quantize(colors=128, method=Image.Quantize.MEDIANCUT)
q = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
q[0].save(out, save_all=True, append_images=q[1:], duration=int(1000 / fps), loop=0, optimize=True, disposal=1)
PY

printf '→ %s (%s)\n' "docs/media/demo.mp4" "$(du -h "$OUT/demo.mp4" | cut -f1)"
printf '→ %s (%s, first %ss of %ss)\n' "docs/media/demo.gif" "$(du -h "$OUT/demo.gif" | cut -f1)" "$SECS" "$DURATION"
printf '→ %s\n' "docs/media/demo-poster.png"
