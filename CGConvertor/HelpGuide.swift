import Foundation
import AppKit

/// Deschide ghidul de utilizare PDF — un singur fisier, RO/EN/ES una dupa
/// alta (aceeasi conventie ca CursorPro/GDCVault). Bundle-uit ca resursa
/// in target-ul Xcode (vezi project.pbxproj — referinta la
/// ../installer/Instructiuni_Utilizare.pdf), NU Bundle.module (proiect
/// Xcode clasic, nu SPM).
///
/// [2026-09-06] Adaugat — pana acum CGConvertor nu avea NICIUN meniu
/// Ajutor/Help cu acces la ghid, spre deosebire de restul aplicatiilor
/// GDC (CursorPro, GDCVault, MacMasterControlPro).
enum HelpGuide {
    static func openPDF() {
        if let url = Bundle.main.url(forResource: "Instructiuni_Utilizare", withExtension: "pdf") {
            NSWorkspace.shared.open(url)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Ghidul nu e încă disponibil"
        alert.informativeText = "Fișierul PDF de ghid nu a fost încă adăugat la această versiune a aplicației."
        alert.alertStyle = .informational
        alert.runModal()
    }
}
