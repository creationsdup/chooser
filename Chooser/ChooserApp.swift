import SwiftUI
import SwiftData

@main
struct ChooserApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ChoiceList.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            try? FileManager.default.removeItem(at: config.url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch let retryError {
                fatalError("Could not create ModelContainer even after reset: \(retryError)")
            }
            #else
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback]))
                ?? { fatalError("Could not create ModelContainer: \(error)") }()
            #endif
        }
    }()

    @State private var languageManager  = LanguageManager()
    @State private var appearanceManager = AppearanceManager()

    var body: some Scene {
        WindowGroup {
            SplashScreenView {
                RootTabView()
            }
            .environment(languageManager)
            .environment(appearanceManager)
            .preferredColorScheme(appearanceManager.resolvedScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Splash Screen

struct SplashScreenView<Content: View>: View {
    let content: () -> Content

    @Environment(LanguageManager.self)    private var lm
    @Environment(AppearanceManager.self) private var appearance

    @State private var isActive      = false
    @State private var logoScale: CGFloat   = 0.7
    @State private var logoOpacity: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0

    var body: some View {
        if isActive {
            content()
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.3)) {
                        contentOpacity = 1
                    }
                }
        } else {
            ZStack {
                Color(hex: "0E0E10")
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(appearance.accent.opacity(0.16))
                            .frame(width: 130, height: 130)
                        Circle()
                            .strokeBorder(appearance.accent.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 130, height: 130)
                        Image(systemName: "circle.grid.cross.fill")
                            .font(.system(size: 64, weight: .semibold))
                            .foregroundStyle(appearance.accent)
                    }

                    Text("Chooser")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(lm.t("splash.tagline"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "A1A1AA"))
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    logoScale  = 1.0
                    logoOpacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        logoOpacity = 0
                        logoScale   = 1.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isActive = true
                    }
                }
            }
        }
    }
}
