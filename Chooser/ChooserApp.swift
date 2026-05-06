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

    @Environment(LanguageManager.self) private var lm

    @State private var isActive = false

    // ── États d'animation ────────────────────────────────────────────────
    @State private var bgOpacity: Double      = 0
    @State private var glowScale: CGFloat     = 0.4
    @State private var glowOpacity: Double    = 0

    @State private var logoScale: CGFloat     = 0.5
    @State private var logoOffsetY: CGFloat   = -28
    @State private var logoOpacity: Double    = 0

    @State private var titleOffsetY: CGFloat  = 18
    @State private var titleOpacity: Double   = 0

    @State private var taglineOffsetY: CGFloat = 12
    @State private var taglineOpacity: Double  = 0

    @State private var exitScale: CGFloat     = 1.0
    @State private var exitOpacity: Double    = 1.0
    @State private var contentOpacity: Double = 0

    // Couleurs pixel-exact du logo
    private let gradientMint = Color(hex: "50E4B7")
    private let gradientCyan = Color(hex: "2CC8E5")
    private let gradientBlue = Color(hex: "2692F8")

    var body: some View {
        if isActive {
            content()
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.22)) { contentOpacity = 1 }
                }
        } else {
            ZStack {
                // ── Fond ─────────────────────────────────────────────────
                LinearGradient(
                    stops: [
                        .init(color: gradientMint, location: 0),
                        .init(color: gradientCyan, location: 0.45),
                        .init(color: gradientBlue, location: 1),
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .ignoresSafeArea()
                .opacity(bgOpacity)

                // ── Halo ambient derrière le logo ─────────────────────────
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity * exitOpacity)
                    .offset(y: -40)

                // ── Contenu — centré optiquement (légèrement au-dessus) ───
                VStack(spacing: 0) {
                    Spacer()

                    // Logo
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 36))
                        .scaleEffect(logoScale * exitScale)
                        .offset(y: logoOffsetY)
                        .opacity(logoOpacity * exitOpacity)

                    Spacer().frame(height: 36)

                    // Nom — plus grand, avec tracking
                    Text("Choozr")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                        .offset(y: titleOffsetY)
                        .opacity(titleOpacity * exitOpacity)

                    Spacer().frame(height: 18)

                    // Tagline — pattern "— texte —" (sigil typographique)
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 22, height: 0.7)
                        Text(lm.t("splash.tagline"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.52))
                            .multilineTextAlignment(.center)
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 22, height: 0.7)
                    }
                    .offset(y: taglineOffsetY)
                    .opacity(taglineOpacity * exitOpacity)

                    Spacer()
                    // Espace supplémentaire en bas → centre optique
                    Spacer().frame(height: 70)
                }
                .frame(maxWidth: .infinity)
            }
            .onAppear { runSequence() }
        }
    }

    private func runSequence() {
        // Fond
        withAnimation(.easeOut(duration: 0.25)) { bgOpacity = 1 }

        // Halo ambient — s'étend dès le début, plus lentement que le logo
        withAnimation(.spring(response: 0.8, dampingFraction: 0.65).delay(0.04)) {
            glowScale   = 1.0
            glowOpacity = 1.0
        }

        // Logo — tombe avec spring rebondissant
        withAnimation(.spring(response: 0.48, dampingFraction: 0.56).delay(0.07)) {
            logoScale   = 1.0
            logoOffsetY = 0
            logoOpacity = 1.0
        }

        // Titre — monte juste après le logo
        withAnimation(.spring(response: 0.44, dampingFraction: 0.80).delay(0.20)) {
            titleOffsetY = 0
            titleOpacity = 1.0
        }

        // Tagline — arrive en dernier, doucement
        withAnimation(.easeOut(duration: 0.36).delay(0.32)) {
            taglineOffsetY = 0
            taglineOpacity = 1.0
        }

        // ── Sortie ────────────────────────────────────────────────────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            // Logo explose, texte disparaît
            withAnimation(.easeIn(duration: 0.32)) {
                exitScale   = 1.35
                exitOpacity = 0
            }
            // Fond fond 60ms après
            withAnimation(.easeIn(duration: 0.28).delay(0.06)) {
                bgOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isActive = true
            }
        }
    }
}
