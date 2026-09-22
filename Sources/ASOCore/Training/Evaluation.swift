import Foundation

/// Metrics for a popularity model on held-out data.
public struct EvaluationReport: Sendable, Codable, Hashable {
    public var name: String
    public var count: Int
    public var spearman: Double
    public var mae: Double
    public var bandAccuracy: Double
    public var bandWithinOne: Double
    /// confusion[actual][predicted] counts, 5×5.
    public var confusion: [[Int]]
    /// Mean absolute error per actual band.
    public var maePerBand: [Double]

    public init(name: String, actual: [Int], predicted: [Double]) {
        self.name = name
        count = actual.count
        spearman = Evaluation.spearman(actual.map(Double.init), predicted)
        mae = zip(actual, predicted).map { abs(Double($0) - $1) }.reduce(0, +) / Double(max(1, actual.count))
        var conf = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        var exact = 0, within = 0
        var errSum = Array(repeating: 0.0, count: 5), errN = Array(repeating: 0, count: 5)
        for (a, p) in zip(actual, predicted) {
            let ab = PopularityBand(index: a).rawValue
            let pb = PopularityBand(index: Int(p.rounded())).rawValue
            conf[ab][pb] += 1
            if ab == pb { exact += 1 }
            if abs(ab - pb) <= 1 { within += 1 }
            errSum[ab] += abs(Double(a) - p)
            errN[ab] += 1
        }
        confusion = conf
        bandAccuracy = Double(exact) / Double(max(1, actual.count))
        bandWithinOne = Double(within) / Double(max(1, actual.count))
        maePerBand = (0..<5).map { errN[$0] == 0 ? 0 : errSum[$0] / Double(errN[$0]) }
    }
}

public enum Evaluation {
    /// Spearman rank correlation with average ranks for ties.
    public static func spearman(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, a.count > 2 else { return 0 }
        let ra = ranks(a), rb = ranks(b)
        let ma = ra.reduce(0, +) / Double(ra.count), mb = rb.reduce(0, +) / Double(rb.count)
        var num = 0.0, da = 0.0, db = 0.0
        for i in 0..<ra.count {
            num += (ra[i] - ma) * (rb[i] - mb)
            da += (ra[i] - ma) * (ra[i] - ma)
            db += (rb[i] - mb) * (rb[i] - mb)
        }
        return da == 0 || db == 0 ? 0 : num / sqrt(da * db)
    }

    static func ranks(_ v: [Double]) -> [Double] {
        let sorted = v.enumerated().sorted { $0.element < $1.element }
        var r = Array(repeating: 0.0, count: v.count)
        var i = 0
        while i < sorted.count {
            var j = i
            while j + 1 < sorted.count, sorted[j + 1].element == sorted[i].element { j += 1 }
            let avg = Double(i + j) / 2 + 1
            for k in i...j { r[sorted[k].offset] = avg }
            i = j + 1
        }
        return r
    }
}
