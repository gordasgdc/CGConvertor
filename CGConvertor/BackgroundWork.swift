import Foundation

/// Lucru blocant (ffprobe, ffmpeg, citiri de fișiere) în AFARA firului principal, cu concurență limitată.
///
/// Motiv: proiectul are `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iar închiderile din `Task.detached`
/// moștenesc acea izolare — deci rulau efectiv pe firul principal și blocau interfața la fiecare clip.
/// `OperationQueue` rulează pe fire de fundal reale; limita evită sute de procese simultane.
enum BackgroundWork {
    nonisolated private static let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "cgc.background"
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = max(2, min(4, ProcessInfo.processInfo.activeProcessorCount / 2))
        return q
    }()

    /// Varianta cu rezultat, pentru apeluri `async` (nu blochează firul principal).
    nonisolated static func async<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { c in queue.addOperation { c.resume(returning: work()) } }
    }

    nonisolated static func run(_ work: @escaping @Sendable () -> Void) {
        queue.addOperation(work)
    }
}
