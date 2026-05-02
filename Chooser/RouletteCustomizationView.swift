import SwiftUI

// MARK: - Wheel Color Style

enum WheelColorStyle: String, CaseIterable, Identifiable {
    case vivid     = "Vif"
    case pastel    = "Pastel"
    case sombre    = "Sombre"
    case neon      = "Néon"
    case naturel   = "Naturel"
    case arcEnCiel = "Arc-en-ciel"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .vivid:     return "wheelcolor.vivid"
        case .pastel:    return "wheelcolor.pastel"
        case .sombre:    return "wheelcolor.sombre"
        case .neon:      return "wheelcolor.neon"
        case .naturel:   return "wheelcolor.naturel"
        case .arcEnCiel: return "wheelcolor.arcenciel"
        }
    }

    var colors: [Color] {
        switch self {
        case .vivid:
            return [Color(hex: "FF6B6B"), Color(hex: "FF8E53"), Color(hex: "FFE66D"),
                    Color(hex: "4ECDC4"), Color(hex: "A855F7"), Color(hex: "10B981"),
                    Color(hex: "3B82F6"), Color(hex: "EC4899"), Color(hex: "F97316"),
                    Color(hex: "6366F1")]
        case .pastel:
            return [Color(hex: "FFB3BA"), Color(hex: "FFDFBA"), Color(hex: "FFFFBA"),
                    Color(hex: "BAFFC9"), Color(hex: "BAE1FF"), Color(hex: "D4BAFF"),
                    Color(hex: "FFBAEE"), Color(hex: "C9FFE5"), Color(hex: "FFD9BA"),
                    Color(hex: "B3ECFF")]
        case .sombre:
            return [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460"),
                    Color(hex: "533483"), Color(hex: "2C3E50"), Color(hex: "1B4332"),
                    Color(hex: "440D0F"), Color(hex: "3D3D3D"), Color(hex: "2D1B69"),
                    Color(hex: "0A3D0C")]
        case .neon:
            return [Color(hex: "FF006E"), Color(hex: "00F5FF"), Color(hex: "39FF14"),
                    Color(hex: "FF3131"), Color(hex: "FF00FF"), Color(hex: "FFFF00"),
                    Color(hex: "FF6600"), Color(hex: "00FF9F"), Color(hex: "8000FF"),
                    Color(hex: "FF1493")]
        case .naturel:
            return [Color(hex: "8B4513"), Color(hex: "D2691E"), Color(hex: "CD853F"),
                    Color(hex: "6B8E23"), Color(hex: "556B2F"), Color(hex: "8FBC8F"),
                    Color(hex: "BC8F5F"), Color(hex: "A0522D"), Color(hex: "DEB887"),
                    Color(hex: "5D8233")]
        case .arcEnCiel:
            return [Color(hex: "FF0000"), Color(hex: "FF4500"), Color(hex: "FF8C00"),
                    Color(hex: "FFD700"), Color(hex: "9ACD32"), Color(hex: "32CD32"),
                    Color(hex: "00CED1"), Color(hex: "1E90FF"), Color(hex: "8A2BE2"),
                    Color(hex: "FF1493")]
        }
    }

    var icon: String {
        switch self {
        case .vivid:      return "paintpalette.fill"
        case .pastel:     return "cloud.fill"
        case .sombre:     return "moon.stars.fill"
        case .neon:       return "bolt.fill"
        case .naturel:    return "leaf.fill"
        case .arcEnCiel:  return "rainbow"
        }
    }
}

// MARK: - Pointer Style

enum PointerStyle: String, CaseIterable, Identifiable {
    case pin      = "Épingle"
    case arrow    = "Flèche"
    case drop     = "Goutte"
    case diamond  = "Losange"
    case dart     = "Dard"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .pin:     return "pointer.pin"
        case .arrow:   return "pointer.arrow"
        case .drop:    return "pointer.drop"
        case .diamond: return "pointer.diamond"
        case .dart:    return "pointer.dart"
        }
    }

    var icon: String {
        switch self {
        case .pin:     return "mappin.fill"
        case .arrow:   return "arrowtriangle.down.fill"
        case .drop:    return "drop.fill"
        case .diamond: return "diamond.fill"
        case .dart:    return "arrow.down.to.line"
        }
    }
}

// MARK: - Pointer Shapes

struct PointerPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

struct PointerArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.45))
            p.addLine(to: CGPoint(x: rect.midX + w * 0.25, y: rect.minY + h * 0.58))
            p.addLine(to: CGPoint(x: rect.midX + w * 0.25, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.22))
            p.addLine(to: CGPoint(x: rect.midX - w * 0.25, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX - w * 0.25, y: rect.minY + h * 0.58))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.45))
            p.closeSubpath()
        }
    }
}

struct PointerDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let r = rect.width / 2
        let cy = rect.minY + r
        var path = Path()
        path.move(to: CGPoint(x: cx + r, y: cy))
        path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addCurve(
            to: CGPoint(x: cx, y: rect.maxY),
            control1: CGPoint(x: cx - r, y: cy + (rect.maxY - cy) * 0.6),
            control2: CGPoint(x: cx - r * 0.3, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: cx + r, y: cy),
            control1: CGPoint(x: cx + r * 0.3, y: rect.maxY),
            control2: CGPoint(x: cx + r, y: cy + (rect.maxY - cy) * 0.6)
        )
        path.closeSubpath()
        return path
    }
}

struct PointerDiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

struct PointerDartShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let cx = rect.midX
            p.move(to: CGPoint(x: cx, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.62))
            p.addLine(to: CGPoint(x: cx + rect.width * 0.16, y: rect.minY + rect.height * 0.52))
            p.addLine(to: CGPoint(x: cx + rect.width * 0.16, y: rect.minY))
            p.addLine(to: CGPoint(x: cx - rect.width * 0.16, y: rect.minY))
            p.addLine(to: CGPoint(x: cx - rect.width * 0.16, y: rect.minY + rect.height * 0.52))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.62))
            p.closeSubpath()
        }
    }
}

// Universal pointer shape wrapper that delegates to the right shape
struct PointerShape: Shape {
    let style: PointerStyle
    func path(in rect: CGRect) -> Path {
        switch style {
        case .pin:     return PointerPinShape().path(in: rect)
        case .arrow:   return PointerArrowShape().path(in: rect)
        case .drop:    return PointerDropShape().path(in: rect)
        case .diamond: return PointerDiamondShape().path(in: rect)
        case .dart:    return PointerDartShape().path(in: rect)
        }
    }
}

// MARK: - Mini Wheel Canvas

struct MiniWheelCanvas: View {
    let colors: [Color]
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2 - 1
            let count = min(8, colors.count)
            let segAngle = 2 * Double.pi / Double(count)

            for i in 0..<count {
                let startAngle = Double(i) * segAngle - Double.pi / 2
                let endAngle = startAngle + segAngle

                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                            startAngle: .radians(startAngle), endAngle: .radians(endAngle),
                            clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .color(colors[i % colors.count]))

                var line = Path()
                line.move(to: center)
                line.addLine(to: CGPoint(
                    x: center.x + radius * cos(startAngle),
                    y: center.y + radius * sin(startAngle)
                ))
                context.stroke(line, with: .color(.white.opacity(0.35)), lineWidth: 1)
            }

            var ring = Path()
            ring.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2))
            context.stroke(ring, with: .color(.white.opacity(0.5)), lineWidth: 2)

            let capR: CGFloat = 5
            var cap = Path()
            cap.addEllipse(in: CGRect(x: center.x - capR, y: center.y - capR,
                                      width: capR * 2, height: capR * 2))
            context.fill(cap, with: .color(.white))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Customization View

struct RouletteCustomizationView: View {
    @AppStorage("wheelColorStyle") private var wheelColorStyleRaw = WheelColorStyle.vivid.rawValue
    @AppStorage("pointerStyle")    private var pointerStyleRaw    = PointerStyle.pin.rawValue
    @AppStorage("wheelFrameStyle") private var wheelFrameStyleRaw = WheelFrameStyle.simple.rawValue

    @Environment(\.dismiss)   private var dismiss
    @Environment(\.appTheme)  private var theme
    @Environment(LanguageManager.self) private var lm

    private var selectedColorStyle: WheelColorStyle {
        WheelColorStyle(rawValue: wheelColorStyleRaw) ?? .vivid
    }
    private var selectedPointerStyle: PointerStyle {
        PointerStyle(rawValue: pointerStyleRaw) ?? .pin
    }
    private var selectedFrameStyle: WheelFrameStyle {
        WheelFrameStyle(rawValue: wheelFrameStyleRaw) ?? .simple
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        colorStyleSection

                        separator

                        pointerStyleSection

                        separator

                        frameStyleSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(lm.t("roulette.customize.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lm.t("button.ok")) { dismiss() }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.primary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Color Style Section

    private var colorStyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: lm.t("roulette.customize.colors"), icon: "paintpalette.fill")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(WheelColorStyle.allCases) { style in
                    let isSelected = style == selectedColorStyle
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            wheelColorStyleRaw = style.rawValue
                        }
                    } label: {
                        VStack(spacing: 8) {
                            MiniWheelCanvas(colors: style.colors, size: 72)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            isSelected ? theme.primary : .white.opacity(0.12),
                                            lineWidth: isSelected ? 3 : 1.5
                                        )
                                )
                                .shadow(color: isSelected ? theme.primary.opacity(0.5) : .clear, radius: 10)

                            Text(lm.t(style.labelKey))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? theme.primary.opacity(0.18) : .white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            isSelected ? theme.primary.opacity(0.45) : .white.opacity(0.06),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
    }

    // MARK: - Pointer Style Section

    private var pointerStyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: lm.t("roulette.customize.pointer"), icon: "arrowtriangle.down.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PointerStyle.allCases) { style in
                        let isSelected = style == selectedPointerStyle
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                pointerStyleRaw = style.rawValue
                            }
                        } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(isSelected ? 0.1 : 0.06))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    isSelected ? theme.primary : .white.opacity(0.08),
                                                    lineWidth: isSelected ? 2.5 : 1
                                                )
                                        )

                                    PointerShape(style: style)
                                        .fill(LinearGradient(
                                            colors: [.white, Color(hex: "CCCCCC")],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .frame(width: 22, height: 28)
                                }
                                .shadow(color: isSelected ? theme.primary.opacity(0.45) : .clear, radius: 8)

                                Text(lm.t(style.labelKey))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? theme.primary.opacity(0.18) : .white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                isSelected ? theme.primary.opacity(0.45) : .white.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Frame Style Section

    private var frameStyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: lm.t("roulette.customize.frame"), icon: "circle.dashed")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WheelFrameStyle.allCases) { style in
                        let isSelected = style == selectedFrameStyle
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                wheelFrameStyleRaw = style.rawValue
                            }
                        } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(isSelected ? 0.1 : 0.06))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    isSelected ? theme.primary : .white.opacity(0.08),
                                                    lineWidth: isSelected ? 2.5 : 1
                                                )
                                        )

                                    framePreview(style: style, size: 44)
                                }
                                .shadow(color: isSelected ? theme.primary.opacity(0.45) : .clear, radius: 8)

                                Text(lm.t(style.labelKey))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? theme.primary.opacity(0.18) : .white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                isSelected ? theme.primary.opacity(0.45) : .white.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.primary)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(0.8)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
    }

    @ViewBuilder
    private func framePreview(style: WheelFrameStyle, size: CGFloat) -> some View {
        switch style {
        case .none:
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: size, height: size)
        case .simple:
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
        case .thick:
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(theme.primary, lineWidth: 5))
                .shadow(color: theme.primary.opacity(0.3), radius: 4)
        case .glow:
            ZStack {
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: size, height: size)
                Circle()
                    .stroke(Color(hex: "FFE66D").opacity(0.5), lineWidth: 6)
                    .frame(width: size, height: size)
                    .blur(radius: 4)
                Circle()
                    .stroke(Color(hex: "FFE66D"), lineWidth: 2)
                    .frame(width: size, height: size)
            }
        case .casino:
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "FFA000"), Color(hex: "FFD700"),
                                         Color(hex: "FFF0AA"), Color(hex: "FFD700")],
                                center: .center
                            ),
                            lineWidth: 5
                        )
                        .frame(width: size, height: size)
                )
        case .premium:
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Color(hex: "C8C8C8"), Color(hex: "FFFFFF"), Color(hex: "888888"),
                                         Color(hex: "E8E8E8"), Color(hex: "C8C8C8")],
                                center: .center
                            ),
                            lineWidth: 4
                        )
                        .frame(width: size, height: size)
                )
        }
    }
}

#Preview {
    RouletteCustomizationView()
        .environment(\.appTheme, .coral)
}
