import SwiftUI
import SwiftData

@main
struct ChooserApp: App {
    private let sharedModelContainer: ModelContainer
    private let storageFallback: Bool

    init() {
        let schema = Schema([ChoiceList.self])
        let persistent = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [persistent])
            storageFallback = false
        } catch {
            #if DEBUG
            try? FileManager.default.removeItem(at: persistent.url)
            do {
                sharedModelContainer = try ModelContainer(for: schema, configurations: [persistent])
                storageFallback = false
            } catch let retryError {
                fatalError("Could not create ModelContainer even after reset: \(retryError)")
            }
            #else
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let container = try? ModelContainer(for: schema, configurations: [inMemory]) else {
                fatalError("Could not create in-memory ModelContainer")
            }
            sharedModelContainer = container
            storageFallback = true
            #endif
        }
    }

    @State private var languageManager   = LanguageManager()
    @State private var appearanceManager = AppearanceManager()
    @State private var showStorageAlert  = false

    var body: some Scene {
        WindowGroup {
            SplashScreenView {
                RootTabView()
            }
            .environment(languageManager)
            .environment(appearanceManager)
            .preferredColorScheme(appearanceManager.resolvedScheme)
            .dynamicTypeSize(.xSmall ... .xxxLarge)
            .transaction { t in
                if appearanceManager.animationsReduced { t.animation = nil }
            }
            .alert(languageManager.t("storage.error.title"), isPresented: $showStorageAlert) {
                Button(languageManager.t("button.ok"), role: .cancel) { }
            } message: {
                Text(languageManager.t("storage.error.message"))
            }
            .onAppear { showStorageAlert = storageFallback }
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
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .shadow(color: appearance.accent.opacity(0.4), radius: 20, x: 0, y: 8)

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
