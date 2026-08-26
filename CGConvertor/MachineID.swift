import Foundation
import IOKit
import CryptoKit

/// Port 1:1 al MachineID.swift din GDCVault/DataMover — aceeași sursă
/// (IOPlatformUUID), aceeași derivare, ca un ID afișat aici să se
/// potrivească exact cu ce se așteaptă din partea de Furnizor.
public enum MachineID {
    private static func rawPlatformUUID() -> String {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/")
        guard entry != 0 else { return "mac-machine-id-unavailable" }
        defer { IOObjectRelease(entry) }

        guard let cfValue = IORegistryEntryCreateCFProperty(entry, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) else {
            return "mac-machine-id-unavailable"
        }
        let uuidRef = cfValue.takeRetainedValue()
        return (uuidRef as? String) ?? "mac-machine-id-unavailable"
    }

    public static var hashBytes: [UInt8] {
        Array(SHA512.hash(data: Data(rawPlatformUUID().utf8)).prefix(6))
    }

    public static var display: String {
        LicenseCore.base32Encode(Data(hashBytes))
    }
}
