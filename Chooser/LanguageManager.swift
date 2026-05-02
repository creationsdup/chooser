import SwiftUI

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system  = "system"
    case french  = "fr"
    case english = "en"
    var id: String { rawValue }
}

// MARK: - Language Manager

@Observable
final class LanguageManager {

    var language: AppLanguage = {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        return AppLanguage(rawValue: raw) ?? .system
    }() {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }

    // MARK: Translation

    func t(_ key: String) -> String {
        let lang = resolvedLanguageCode
        return Translations.table[key]?[lang]
            ?? Translations.table[key]?["fr"]
            ?? key
    }

    var resolvedLanguageCode: String {
        switch language {
        case .system:
            let code = Locale.current.language.languageCode?.identifier ?? "fr"
            return ["fr", "en"].contains(code) ? code : "fr"
        case .french:  return "fr"
        case .english: return "en"
        }
    }

    // MARK: Display helpers

    func displayName(for lang: AppLanguage) -> String {
        switch lang {
        case .system:  return t("lang.system")
        case .french:  return "Français"
        case .english: return "English"
        }
    }

    func detailName(for lang: AppLanguage) -> String? {
        lang == .system ? t("lang.system.detail") : nil
    }
}

// MARK: - All translations

private enum Translations {

    static let table: [String: [String: String]] = [

        // ── Tabs ──────────────────────────────────────────────────────────
        "tab.home":       ["fr": "Accueil",    "en": "Home"],
        "tab.lists":      ["fr": "Mes Listes", "en": "My Lists"],
        "tab.appearance": ["fr": "Apparence",  "en": "Appearance"],
        "tab.settings":   ["fr": "Réglages",   "en": "Settings"],

        // ── Splash ────────────────────────────────────────────────────────
        "splash.tagline": ["fr": "Le hasard, c'est toi qui décides",
                           "en": "Luck is in your hands"],

        // ── Home ──────────────────────────────────────────────────────────
        "home.title":    ["fr": "Chooser", "en": "Chooser"],
        "home.subtitle": ["fr": "Quel jeu veux-tu jouer ?", "en": "What game do you want to play?"],

        // ── Picker modes — titles ─────────────────────────────────────────
        "mode.fingerChooser.title":    ["fr": "Finger Chooser",    "en": "Finger Chooser"],
        "mode.roulette.title":         ["fr": "Roulette",          "en": "Roulette"],
        "mode.dice.title":             ["fr": "Dés",               "en": "Dice"],
        "mode.randomDraw.title":       ["fr": "Tirage au Sort",    "en": "Random Draw"],
        "mode.coinFlip.title":         ["fr": "Pile ou Face",      "en": "Coin Flip"],
        "mode.numberRoulette.title":   ["fr": "Nombre Aléatoire",  "en": "Random Number"],
        "mode.luckyArrow.title":       ["fr": "Flèche du Hasard",  "en": "Lucky Arrow"],
        "mode.weightedRoulette.title": ["fr": "Roue Pondérée",     "en": "Weighted Wheel"],
        "mode.ranking.title":          ["fr": "Classement",        "en": "Ranking"],

        // ── Picker modes — subtitles ──────────────────────────────────────
        "mode.fingerChooser.subtitle":    ["fr": "Pose plusieurs doigts, un sera choisi",
                                           "en": "Place multiple fingers, one will be chosen"],
        "mode.roulette.subtitle":         ["fr": "Fais tourner la roue du destin",
                                           "en": "Spin the wheel of destiny"],
        "mode.dice.subtitle":             ["fr": "Lance un ou plusieurs dés",
                                           "en": "Roll one or more dice"],
        "mode.randomDraw.subtitle":       ["fr": "Pioche un élément de ta liste",
                                           "en": "Pick an item from your list"],
        "mode.coinFlip.subtitle":         ["fr": "Laisse le sort décider",
                                           "en": "Let fate decide"],
        "mode.numberRoulette.subtitle":   ["fr": "Tire un nombre dans une plage définie",
                                           "en": "Pick a number in a defined range"],
        "mode.luckyArrow.subtitle":       ["fr": "Tourne la flèche et laisse le sort décider",
                                           "en": "Spin the arrow and let fate decide"],
        "mode.weightedRoulette.subtitle": ["fr": "Définis tes propres probabilités",
                                           "en": "Set your own probabilities"],
        "mode.ranking.subtitle":          ["fr": "Classe ta liste dans un ordre aléatoire",
                                           "en": "Rank your list in a random order"],

        // ── My Lists ──────────────────────────────────────────────────────
        "lists.title":           ["fr": "Mes Listes",  "en": "My Lists"],
        "lists.empty.title":     ["fr": "Aucune liste", "en": "No lists yet"],
        "lists.empty.body":      ["fr": "Crée ta première liste pour\nl'utiliser dans la Roulette\nou le Tirage au Sort !",
                                  "en": "Create your first list to use\nit in Roulette or Random Draw!"],
        "lists.create":          ["fr": "Créer une liste",  "en": "Create a list"],
        "lists.new.title":       ["fr": "Nouvelle liste",   "en": "New list"],
        "lists.new.nameSection": ["fr": "Nom de la liste",  "en": "List name"],
        "lists.new.placeholder": ["fr": "Ex : Films à regarder…", "en": "e.g. Movies to watch…"],
        "lists.item.singular":   ["fr": "1 élément",   "en": "1 item"],
        "lists.item.plural":     ["fr": "%d éléments", "en": "%d items"],

        // ── List detail ───────────────────────────────────────────────────
        "detail.addPlaceholder": ["fr": "Ajouter un élément…", "en": "Add an item…"],
        "detail.emptyTitle":     ["fr": "Liste vide",           "en": "Empty list"],
        "detail.emptyBody":      ["fr": "Ajoute des éléments ci-dessous !",
                                  "en": "Add items below!"],

        // ── Settings ──────────────────────────────────────────────────────
        "settings.title":         ["fr": "Réglages",            "en": "Settings"],
        "settings.feedback":      ["fr": "Feedback",             "en": "Feedback"],
        "settings.sound":         ["fr": "Sons",                 "en": "Sound"],
        "settings.haptics":       ["fr": "Vibrations",           "en": "Haptics"],
        "settings.preferences":   ["fr": "Préférences",          "en": "Preferences"],
        "settings.defaultMode":   ["fr": "Mode par défaut",      "en": "Default mode"],
        "settings.stats":         ["fr": "Statistiques",         "en": "Statistics"],
        "settings.stats.lists":   ["fr": "Listes créées",        "en": "Lists created"],
        "settings.stats.items":   ["fr": "Éléments au total",    "en": "Total items"],
        "settings.danger":        ["fr": "Zone de danger",       "en": "Danger zone"],
        "settings.reset":         ["fr": "Effacer toutes les données", "en": "Clear all data"],
        "settings.reset.footer":  ["fr": "Supprime toutes les listes et leurs éléments. Cette action est irréversible.",
                                   "en": "Deletes all your lists and items. This action is irreversible."],
        "settings.reset.confirm": ["fr": "Effacer toutes les données ?", "en": "Clear all data?"],
        "settings.reset.action":  ["fr": "Tout effacer",    "en": "Clear all"],
        "settings.reset.message": ["fr": "Toutes tes listes et leurs éléments seront supprimés définitivement.",
                                   "en": "All your lists and items will be permanently deleted."],
        "settings.about":         ["fr": "À propos",  "en": "About"],
        "settings.version":       ["fr": "Version",   "en": "Version"],

        // ── Language ──────────────────────────────────────────────────────
        "settings.language.section": ["fr": "Langue",    "en": "Language"],
        "lang.system":               ["fr": "Automatique", "en": "Automatic"],
        "lang.system.detail":        ["fr": "Suit la langue de l'iPhone",
                                      "en": "Follows iPhone language"],

        // ── Appearance ────────────────────────────────────────────────────
        "personalization.title":           ["fr": "Apparence",          "en": "Appearance"],

        // Color scheme
        "appearance.colorScheme":          ["fr": "Thème",              "en": "Theme"],
        "scheme.system":                   ["fr": "Automatique",        "en": "Auto"],
        "scheme.light":                    ["fr": "Clair",              "en": "Light"],
        "scheme.dark":                     ["fr": "Sombre",             "en": "Dark"],

        // Accent color
        "appearance.accentColor":          ["fr": "Couleur d'accent",   "en": "Accent color"],
        "appearance.accentColor.footer":   ["fr": "Modifie la couleur principale de l'application.",
                                            "en": "Changes the app's primary color."],
        "accent.coral":                    ["fr": "Corail",             "en": "Coral"],
        "accent.blue":                     ["fr": "Bleu",               "en": "Blue"],
        "accent.violet":                   ["fr": "Violet",             "en": "Violet"],
        "accent.green":                    ["fr": "Vert",               "en": "Green"],
        "accent.orange":                   ["fr": "Orange",             "en": "Orange"],
        "accent.rose":                     ["fr": "Rose",               "en": "Rose"],

        // Visual style
        "appearance.visualStyle":          ["fr": "Style visuel",       "en": "Visual style"],
        "appearance.visualStyle.footer":   ["fr": "Définit l'ambiance générale des écrans de jeu.",
                                            "en": "Sets the overall look of game screens."],
        "style.playful":      ["fr": "Dynamique",                        "en": "Playful"],
        "style.playful.desc": ["fr": "Cartes colorées, ambiance fun et énergique",
                               "en": "Colorful cards, fun and energetic vibes"],
        "style.atmos":        ["fr": "Atmos",                           "en": "Atmos"],
        "style.atmos.desc":   ["fr": "Sombre vibrant avec tuiles colorées", "en": "Vibrant dark with colorful tiles"],

        // Experience
        "appearance.experience":           ["fr": "Expérience",         "en": "Experience"],
        "appearance.experience.footer":    ["fr": "Réduire les animations améliore la fluidité sur les appareils plus anciens.",
                                            "en": "Reducing animations improves smoothness on older devices."],
        "appearance.animations.reduced":   ["fr": "Réduire les animations", "en": "Reduce animations"],

        // Legacy roulette/frame keys (still used by RouletteCustomizationView)
        "appearance.numberStyle":          ["fr": "Style « Nombre Aléatoire »", "en": "Random Number style"],
        "appearance.numberStyle.slot":     ["fr": "Slot Machine",       "en": "Slot Machine"],
        "appearance.numberStyle.classic":  ["fr": "Classique",          "en": "Classic"],

        // ── Buttons ───────────────────────────────────────────────────────
        "button.cancel": ["fr": "Annuler",    "en": "Cancel"],
        "button.create": ["fr": "Créer",      "en": "Create"],
        "button.ok":     ["fr": "OK",         "en": "OK"],
        "button.close":  ["fr": "Fermer",     "en": "Close"],
        "button.edit":   ["fr": "Modifier",   "en": "Edit"],
        "button.delete": ["fr": "Supprimer",  "en": "Delete"],
        "button.again":  ["fr": "Recommencer","en": "Again"],
        "button.start":  ["fr": "Démarrer",   "en": "Start"],
        "button.done":   ["fr": "Terminé",    "en": "Done"],
        "button.back":   ["fr": "Retour",     "en": "Back"],
        "button.save":   ["fr": "Enregistrer","en": "Save"],

        // ── Shared states ──────────────────────────────────────────────────
        "state.inProgress": ["fr": "En cours…",  "en": "In progress…"],
        "state.spinning":   ["fr": "Lancer !",    "en": "Spin!"],

        // ── Coin Flip ─────────────────────────────────────────────────────
        "coinflip.hint":   ["fr": "Swipe up ou tape la pièce",
                            "en": "Swipe up or tap the coin"],
        "coinflip.heads":  ["fr": "FACE",  "en": "HEADS"],
        "coinflip.tails":  ["fr": "PILE",  "en": "TAILS"],

        // ── Dice ──────────────────────────────────────────────────────────
        "dice.total":      ["fr": "Total",     "en": "Total"],
        "dice.roll":       ["fr": "Lancer !",  "en": "Roll!"],
        "dice.die":        ["fr": "dé",        "en": "die"],
        "dice.dice":       ["fr": "dés",       "en": "dice"],
        "dice.rolling":    ["fr": "En cours...", "en": "Rolling..."],

        // ── Lucky Arrow ───────────────────────────────────────────────────
        "arrow.spinning":        ["fr": "En rotation…",           "en": "Spinning…"],
        "arrow.submode.arrow":   ["fr": "Flèche",                 "en": "Arrow"],
        "arrow.submode.bottle":  ["fr": "Bouteille",              "en": "Bottle"],
        "bottle.spin.button":    ["fr": "Tourner la bouteille !", "en": "Spin the bottle!"],

        // ── Random Draw ───────────────────────────────────────────────────
        "draw.pickList":            ["fr": "Choisir une liste",    "en": "Pick a list"],
        "draw.allLists":            ["fr": "Toutes les listes",    "en": "All lists"],
        "draw.randomMode.title":    ["fr": "Mode Aléatoire Total", "en": "Total Random Mode"],
        "draw.randomMode.subtitle": ["fr": "Pioche dans toutes vos listes",
                                     "en": "Picks from all your lists"],
        "draw.direct.placeholder":  ["fr": "Ajouter un nom, option…",
                                     "en": "Add a name, option…"],
        "draw.saveAsList":          ["fr": "Enregistrer comme liste",
                                     "en": "Save as list"],
        "draw.ready":               ["fr": "Prêt à tirer",   "en": "Ready to draw"],
        "draw.result":              ["fr": "C'est le résultat !",  "en": "That's the result!"],
        "draw.drawing":             ["fr": "Tirage…",         "en": "Drawing…"],
        "draw.button":              ["fr": "Tirer au sort !", "en": "Draw!"],
        "draw.empty.noLists":       ["fr": "Crée d'abord une liste\ndans l'onglet Mes Listes",
                                     "en": "First create a list\nin the My Lists tab"],
        "draw.empty.listEmpty":     ["fr": "Cette liste est vide.\nAjoute des éléments !",
                                     "en": "This list is empty.\nAdd some items!"],
        "draw.empty.noEntries":     ["fr": "Aucun élément",  "en": "No items"],
        "draw.empty.noEntries.hint":["fr": "Saisis des noms ou options\ndans le champ ci-dessus",
                                     "en": "Type names or options\nin the field above"],
        "draw.save.placeholder":    ["fr": "Ex: Participants, Options…",
                                     "en": "e.g. Participants, Options…"],
        "draw.save.title":          ["fr": "Enregistrer la saisie",  "en": "Save entries"],
        "draw.save.defaultName":    ["fr": "Ma liste",   "en": "My list"],
        "draw.inputMode.savedList": ["fr": "Liste",      "en": "List"],
        "draw.inputMode.direct":    ["fr": "Saisie libre", "en": "Free entry"],

        // ── Roulette ──────────────────────────────────────────────────────
        "roulette.spin":              ["fr": "Lancer !",        "en": "Spin!"],
        "roulette.empty.noLists":     ["fr": "Crée d'abord une liste\ndans l'onglet Mes Listes",
                                       "en": "First create a list\nin the My Lists tab"],
        "roulette.empty.listEmpty":   ["fr": "Cette liste est vide.\nAjoute des éléments !",
                                       "en": "This list is empty.\nAdd some items!"],
        "roulette.empty.min2":        ["fr": "Minimum 2 éléments",
                                       "en": "At least 2 items needed"],
        "roulette.empty.addHint":     ["fr": "Appuie sur « Modifier » pour\najouter des éléments",
                                       "en": "Tap \"Edit\" to\nadd items"],
        "roulette.direct.emptyHint":  ["fr": "Saisis tes éléments ci-dessus",
                                       "en": "Type your items above"],
        "roulette.direct.pasteHint":  ["fr": "Tu peux coller plusieurs lignes\npour en ajouter plusieurs d'un coup",
                                       "en": "You can paste multiple lines\nto add several at once"],
        "roulette.direct.title":      ["fr": "Saisie directe",  "en": "Direct entry"],
        "roulette.direct.placeholder":["fr": "Ajouter un nom, option…",
                                       "en": "Add a name, option…"],
        "roulette.direct.entriesCount":["fr": "%d élément%@ saisi%@",
                                        "en": "%d item%@ entered"],
        "roulette.direct.enterItems": ["fr": "Saisir des éléments…",
                                       "en": "Enter items…"],
        "roulette.pickList":          ["fr": "Choisir une liste",  "en": "Pick a list"],

        // ── Weighted Roulette ──────────────────────────────────────────────
        "weighted.setup.title":      ["fr": "Combien d'options ?",   "en": "How many options?"],
        "weighted.setup.subtitle":   ["fr": "Sélectionne le nombre de cases sur la roue",
                                      "en": "Select the number of slots on the wheel"],
        "weighted.setup.continue":   ["fr": "Continuer",             "en": "Continue"],
        "weighted.customize.title":         ["fr": "Personnalise ta roue",               "en": "Customize your wheel"],
        "weighted.customize.start":         ["fr": "Voir la roue",                       "en": "See the wheel"],
        "weighted.customize.namesRequired": ["fr": "Donne un titre à chaque option",     "en": "Every option needs a title"],
        "wheel.save.title":         ["fr": "Mes roues",                          "en": "My wheels"],
        "wheel.save.namePlaceholder":["fr": "Nom de la roue…",                  "en": "Wheel name…"],
        "wheel.save.action":        ["fr": "Enregistrer",                        "en": "Save"],
        "wheel.save.saved":         ["fr": "Roue enregistrée !",                 "en": "Wheel saved!"],
        "wheel.save.myWheels":      ["fr": "MES ROUES ENREGISTRÉES",             "en": "SAVED WHEELS"],
        "wheel.save.load":               ["fr": "Charger",                        "en": "Load"],
        "wheel.save.myWheels.button":    ["fr": "Mes roues enregistrées",         "en": "My saved wheels"],
        "wheel.load.empty":              ["fr": "Aucune roue enregistrée",        "en": "No saved wheels"],
        "weighted.empty":          ["fr": "Ajoute au moins 2 options\navec un poids supérieur à 0",
                                    "en": "Add at least 2 options\nwith a weight above 0"],
        "weighted.options.title":  ["fr": "Options & Poids",       "en": "Options & Weights"],
        "weighted.probabilities":  ["fr": "PROBABILITÉS",          "en": "PROBABILITIES"],
        "weighted.total":          ["fr": "Total :",               "en": "Total:"],
        "weighted.options.empty":  ["fr": "Appuie sur + pour créer ta première option",
                                    "en": "Tap + to create your first option"],
        "weighted.option.placeholder": ["fr": "Nom de l'option…", "en": "Option name…"],
        "weighted.disclaimer":     ["fr": "Le total ≠ 100% — les probabilités réelles sont recalculées proportionnellement.",
                                    "en": "Total ≠ 100% — real probabilities are recalculated proportionally."],
        "weighted.probability":    ["fr": "Probabilité : %.1f%%",  "en": "Probability: %.1f%%"],

        // ── Finger Chooser ────────────────────────────────────────────────
        "finger.mode.classic":      ["fr": "Classique",  "en": "Classic"],
        "finger.mode.ranking":      ["fr": "Classement", "en": "Ranking"],
        "finger.mode.links":        ["fr": "Liens",      "en": "Links"],
        "finger.mode.classic.desc": ["fr": "Un gagnant tiré au sort\nparmi tous les doigts posés.",
                                     "en": "One winner randomly picked\nfrom all placed fingers."],
        "finger.mode.ranking.desc": ["fr": "Chaque doigt reçoit un rang\naléatoire de 1 à N.",
                                     "en": "Each finger is assigned\na random rank from 1 to N."],
        "finger.mode.links.desc":   ["fr": "Les doigts sont associés\nen paires aléatoires.",
                                     "en": "Fingers are randomly\nmatched into pairs."],
        "finger.mode.section":      ["fr": "Mode de jeu",
                                     "en": "Game mode"],
        "finger.mode.subtitle":     ["fr": "Choisissez comment désigner les joueurs",
                                     "en": "Choose how to designate players"],
        "finger.winners.title":     ["fr": "Nombre de gagnants",
                                     "en": "Number of winners"],
        "finger.start":             ["fr": "Commencer",
                                     "en": "Start"],
        "finger.waiting.classic":   ["fr": "Posez 2 à 5 doigts\nsur l'écran",
                                     "en": "Place 2 to 5 fingers\non the screen"],
        "finger.waiting.ranking":   ["fr": "Posez les doigts\npour les classer",
                                     "en": "Place fingers\nto rank them"],
        "finger.waiting.links":     ["fr": "Posez les doigts\npour les associer",
                                     "en": "Place fingers\nto pair them"],
        "finger.detected":          ["fr": "%d doigt%@ détecté%@",
                                     "en": "%d finger%@ detected%@"],
        "finger.unsupported":       ["fr": "Finger Chooser nécessite\nun écran tactile",
                                     "en": "Finger Chooser requires\na touchscreen"],

        // ── Number Roulette ───────────────────────────────────────────────
        "numberroulette.classic.title": ["fr": "Roulette de Nombres",  "en": "Number Roulette"],
        "numberroulette.range.label":   ["fr": "sur [%d – %d]",        "en": "in [%d – %d]"],
        "numberroulette.spinning":      ["fr": "Tirage en cours…",     "en": "Drawing…"],
        "numberroulette.mode.hint":     ["fr": "Choisis comment afficher ton nombre aléatoire",
                                         "en": "Choose how to display your random number"],
        "numberroulette.mode.title":    ["fr": "Mode de tirage",       "en": "Draw mode"],
        "numberroulette.slot.title":    ["fr": "Roulette de Casino",   "en": "Casino Slot Machine"],
        "numberroulette.slot.desc":     ["fr": "4 tambours animés comme une vraie machine à sous. Tire la manette et laisse les chiffres s'aligner !",
                                         "en": "4 animated reels like a real slot machine. Pull the lever and let the numbers align!"],
        "numberroulette.classic.desc.title": ["fr": "Nombre Libre", "en": "Free Number"],
        "numberroulette.classic.desc":  ["fr": "Un grand nombre animé dans l'intervalle de ton choix. Simple, rapide et efficace.",
                                         "en": "A large animated number in your chosen range. Simple, fast and effective."],
        "numberroulette.range.from":    ["fr": "De",  "en": "From"],
        "numberroulette.range.to":      ["fr": "À",   "en": "To"],

        // ── Roulette Customization ────────────────────────────────────────
        "roulette.customize.title":        ["fr": "Personnaliser la roue", "en": "Customize wheel"],
        "roulette.customize.colors":       ["fr": "Couleurs de la roue",   "en": "Wheel colors"],
        "roulette.customize.pointer":      ["fr": "Type de flèche",        "en": "Arrow type"],
        "roulette.customize.frame":        ["fr": "Cadre de la roue",      "en": "Wheel frame"],
        "wheelcolor.vivid":     ["fr": "Vif",        "en": "Vivid"],
        "wheelcolor.pastel":    ["fr": "Pastel",     "en": "Pastel"],
        "wheelcolor.sombre":    ["fr": "Sombre",     "en": "Dark"],
        "wheelcolor.neon":      ["fr": "Néon",       "en": "Neon"],
        "wheelcolor.naturel":   ["fr": "Naturel",    "en": "Natural"],
        "wheelcolor.arcenciel": ["fr": "Arc-en-ciel","en": "Rainbow"],
        "pointer.pin":      ["fr": "Épingle",  "en": "Pin"],
        "pointer.arrow":    ["fr": "Flèche",   "en": "Arrow"],
        "pointer.drop":     ["fr": "Goutte",   "en": "Drop"],
        "pointer.diamond":  ["fr": "Losange",  "en": "Diamond"],
        "pointer.dart":     ["fr": "Dard",     "en": "Dart"],
        "wheelframe.none":    ["fr": "Aucun",    "en": "None"],
        "wheelframe.simple":  ["fr": "Simple",   "en": "Simple"],
        "wheelframe.thick":   ["fr": "Épais",    "en": "Thick"],
        "wheelframe.glow":    ["fr": "Lumineux", "en": "Glow"],
        "wheelframe.casino":  ["fr": "Casino",   "en": "Casino"],
        "wheelframe.premium": ["fr": "Premium",  "en": "Premium"],

        // ── Ranking ───────────────────────────────────────────────────────
        "ranking.ready.title":       ["fr": "Prêt à classer",              "en": "Ready to rank"],
        "ranking.ready.subtitle":    ["fr": "Les participants seront classés\ndans un ordre aléatoire",
                                      "en": "Participants will be ranked\nin a random order"],
        "ranking.button":            ["fr": "Classer !",                   "en": "Rank it!"],
        "ranking.button.again":      ["fr": "Reclasser !",                 "en": "Rank again!"],
        "ranking.revealing":         ["fr": "Révélation…",                 "en": "Revealing…"],
        "ranking.empty.min2":        ["fr": "Minimum 2 participants",      "en": "At least 2 participants needed"],
        "ranking.direct.placeholder":["fr": "Ajouter un participant…",     "en": "Add a participant…"],
    ]
}
