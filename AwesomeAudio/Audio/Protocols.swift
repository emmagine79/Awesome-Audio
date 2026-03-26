import Foundation

protocol StreamingProcessor {
    var sampleRate: Double { get }
    var latencySamples: Int { get }
    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int)
    func reset()
}

protocol AudioAnalyzer {
    func analyze(_ buffer: UnsafePointer<Float>, frameCount: Int)
    func finalize() -> AnalysisResult
    func reset()
}

protocol AnalysisDerivedProcessor: StreamingProcessor {
    func configure(from result: AnalysisResult)
}
