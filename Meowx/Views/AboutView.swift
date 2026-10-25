import AppKit
import SwiftUI

struct AboutView: View {
    @State private var model = PlayerModel.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: Theme.s16) {
            MeowxMark(side: Theme.mark)
                .foregroundStyle(Theme.primary)
                .padding(.top, Theme.s8)
                .accessibilityLabel("Meowx")
            Text("Meowx")
                .font(Theme.title)
                .foregroundStyle(Theme.primary)
            Text(version.isEmpty ? "Version unknown" : "Version \(version)")
                .font(Theme.body)
                .foregroundStyle(Theme.secondary)
            Text("Free software under the GNU General Public License v3.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: Theme.s8) {
                Link("GitHub", destination: Self.github)
                Link("License", destination: Self.license)
            }
            .font(Theme.body)
            .meowxHit()
        }
        .padding(Theme.s24)
        .frame(width: Theme.sheetNarrow)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(model.settings.appearance == .dark ? .dark : nil)
    }

    private static let github = URL(string: "https://github.com/Cappy7/Meowx")!
    private static let license = URL(string: "https://github.com/Cappy7/Meowx/blob/main/LICENSE")!
}
