import Foundation

/// Nume de folder pentru datele aplicației (Application Support, Logs). Build-ul DEBUG de test izolat
/// (`CGC_NO_KEYCHAIN=1`) folosește foldere proprii, ca să nu citească sau scrie licența, presetările,
/// istoricul ori logul aplicației instalate. Release folosește mereu `CGConvertor`.
nonisolated enum AppIsolation {
    static let isolatedTest: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["CGC_NO_KEYCHAIN"] == "1"
        #else
        return false
        #endif
    }()
    static var folderName: String { isolatedTest ? "CGConvertor-UITest" : "CGConvertor" }
}
