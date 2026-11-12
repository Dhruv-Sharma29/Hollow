import SwiftUI

/// First-run tour: three short pages, then connect. Reopened from "Take the tour again".
struct OnboardingView: View {
    let drive: Drive
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var page = 0

    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            hero
            VStack(spacing: 12) {
                Text(title)
                    .font(.title.weight(.semibold))
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                extras
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .id(page)
            .transition(.opacity)
            Spacer(minLength: 0)
            footer
                .padding(24)
        }
        .frame(width: 540, height: 500)
        .ignoresSafeArea()   // the art runs under the hidden title bar
        .background(.background)
        .animation(.default, value: page)
        .animation(.default, value: drive.phase)
        .onAppear {
            BringForward.now()   // menu-bar apps don't come to the front by themselves
            if drive.signedIn { page = lastPage }
        }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack {
            HollowScene()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            Group {
                switch page {
                case 0:
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 112, height: 112)
                        .accessibilityLabel("Hollow")
                case 1: StreamingDemo()
                case 2: badge("lock.shield")
                default:
                    if drive.isSigningIn {
                        ProgressView()
                            .controlSize(.large)
                            .frame(width: 88, height: 88)
                            .background(.regularMaterial, in: .circle)
                    } else {
                        badge(drive.phase == .mounted ? "checkmark" : "link.icloud")
                    }
                }
            }
            .padding(.top, 24)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .id(page)
        }
        .frame(height: 240)
    }

    private func badge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(.tint)
            .frame(width: 88, height: 88)
            .background(.regularMaterial, in: .circle)
    }

    // MARK: Words

    private var title: String {
        switch page {
        case 0: "Your Google Drive, as a disk"
        case 1: "Only what you open comes down"
        case 2: "Hollow sees only its own folder"
        default:
            if drive.isSigningIn { "Finish in your browser" }
            else if drive.signedIn { drive.phase == .mounted ? "Hollow is ready" : "Almost ready" }
            else { "Connect your Drive" }
        }
    }

    private var message: String {
        switch page {
        case 0: "Hollow puts your Drive in Finder. It works like any folder, but its files don't take up space on your Mac."
        case 1: "Play a 48 GB film and Hollow fetches just the part on screen. Skip ahead and it fetches that part instead."
        case 2: "Hollow can read the files it puts in your Drive, and nothing else. Your files go straight between your Mac and Google."
        default:
            if drive.isSigningIn { "Sign in with Google in the browser window that just opened." }
            else if drive.signedIn { drive.phase == .mounted ? "Press ⌃⌥H from any app to search your Drive. It's also in Finder at ~/Hollow." : drive.status }
            else { "You'll sign in with Google in your browser. Hollow never sees your password." }
        }
    }

    @ViewBuilder private var extras: some View {
        if page == lastPage {
            if !drive.signedIn, case .failed(let why) = drive.phase {
                Text(why).font(.callout).foregroundStyle(.red)
            }
            if drive.signedIn {
                Toggle("Open Hollow at login", isOn: Binding(get: { drive.opensAtLogin }, set: drive.setOpensAtLogin))
                    .toggleStyle(.checkbox)
                    .padding(.top, 8)
                if let error = drive.loginItemError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0...lastPage, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .frame(width: i == page ? 20 : 8, height: 8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Page \(page + 1) of \(lastPage + 1)")

            Spacer()

            if page > 0, page < lastPage || !drive.signedIn, !drive.isSigningIn {
                Button("Back") { page -= 1 }
                    .buttonBorderShape(.capsule)
            }
            primaryButton
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
    }

    @ViewBuilder private var primaryButton: some View {
        if page < lastPage {
            Button("Continue") { page += 1 }
        } else if drive.isSigningIn {
            Button("Cancel") { drive.cancelSignIn() }
        } else if drive.signedIn {
            Button(drive.phase == .mounted ? "Open in Finder" : "Done") {
                if drive.phase == .mounted { drive.openInFinder() }
                dismissWindow()
            }
        } else {
            Button("Connect Google Drive") { Task { await drive.signIn() } }
                .disabled(drive.rclone == nil)
        }
    }
}
