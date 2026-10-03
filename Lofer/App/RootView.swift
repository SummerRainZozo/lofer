import SwiftUI

/// Decides which screen is showing (splash → home → care) and hosts page navigation
/// (Body history, Episode, Care summary, Profile, Typography lab).
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $app.path) {
            ZStack {
                LoferBackground()
                HorizonGlow(raised: app.screen != .splash, dimmed: app.screen == .care)
                switch app.screen {
                case .splash: SplashView { app.finishSplash() }
                case .home: HomeView().transition(.opacity)
                case .care: CareView(model: app.care).transition(.opacity)
                }
                if app.input.visible { InputBar().transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppModel.Page.self) { page in
                Group {
                    switch page {
                    case .history: BodyHistoryView()
                    case .episode(let id): EpisodeDetailView(episodeId: id)
                    case .report(let g): CareSummaryView(initialGroup: g)
                    case .profile: ProfileView()
                    case .typography: TypographyLabView()
                    }
                }
                .toolbarBackground(Color.loferInk, for: .navigationBar)
            }
        }
        .tint(.loferPeach)
    }
}

/// The planet-like horizon glow from the brand board, low on the screen.
struct HorizonGlow: View {
    var raised: Bool
    var dimmed: Bool
    var body: some View {
        GeometryReader { geo in
            Ellipse()
                .fill(Color(hex: 0x0A0808))
                .frame(width: geo.size.width * 1.9, height: geo.size.height)
                .overlay(Ellipse().stroke(Color(hex: 0xF3D2BA).opacity(0.55), lineWidth: 1))
                .shadow(color: Color.loferPeach.opacity(0.18), radius: 30, y: -12)
                .position(x: geo.size.width / 2, y: geo.size.height * (raised ? (dimmed ? 1.36 : 1.24) : 1.6))
                .opacity(raised ? (dimmed ? 0.55 : 1) : 0)
                .animation(.timingCurve(0.22, 0.7, 0.12, 1, duration: 1.6), value: raised)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
