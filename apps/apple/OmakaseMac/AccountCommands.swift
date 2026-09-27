import SwiftUI

/// "Sign Out…" in the app menu (#224), until Settings hosts it (#228).
struct AccountCommands: Commands {
    let isEnabled: Bool
    let signOut: () -> Void

    var body: some Commands {
        CommandGroup(before: .appTermination) {
            Button("Sign Out…") { signOut() }
                .disabled(!isEnabled)
            Divider()
        }
    }
}
