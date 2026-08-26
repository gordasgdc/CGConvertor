import Foundation

/// Port 1:1 al WhatsAppLink.swift din GDCVault/DataMover — același număr
/// de contact, reconstruit din bucăți (nu literal contiguu) ca să nu
/// apară ca șir ușor de recoltat de crawlere.
enum WhatsAppLink {
    private static let parts = ["34", "643", "109", "970"]

    private static var number: String { parts.joined() }

    static func url(text: String? = nil) -> URL {
        var comps = URLComponents(string: "https://wa.me/\(number)")!
        if let text {
            comps.queryItems = [URLQueryItem(name: "text", value: text)]
        }
        return comps.url!
    }
}
