import OmakaseAPI
import SwiftUI

@main
struct OmakaseMacApp: App {
    var body: some Scene {
        WindowGroup("Omakase") {
            Text("Omakase - \(APIDay.today().string)")
                .frame(minWidth: 480, minHeight: 320)
        }
    }
}
