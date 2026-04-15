import SwiftUI
import AppKit

// MARK: - TopBar (header compacto con branding + acciones)
struct TopBar: View {
    var title: String = "Buscafondos"
    var onRefresh: () -> Void
    var onExpand: (() -> Void)? = nil
    @EnvironmentObject var env: AppEnvironment

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            Text(title)
                .font(Typography.titleMD)
                .foregroundStyle(Palette.primary)
            Spacer()
            if env.isSyncing {
                ProgressView().controlSize(.small)
            } else {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.onSurfaceVariant)
            }
            if let onExpand {
                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.onSurfaceVariant)
                .help("Abrir en ventana")
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.error)
            .help("Salir de Buscafondos (⌘Q)")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Palette.surfaceContainerLow)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.outlineVariant.opacity(0.15))
                .frame(height: 0.5)
        }
    }
}

// MARK: - BottomNavBar
enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, fondos, carga, evolucion
    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .fondos:    return "Fondos"
        case .carga:     return "Carga"
        case .evolucion: return "Evolución"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .fondos:    return "building.columns.fill"
        case .carga:     return "plus.circle.fill"
        case .evolucion: return "chart.xyaxis.line"
        }
    }
}

struct BottomNavBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(tab.label.uppercased())
                            .font(Typography.labelXS)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(selected == tab
                                  ? Palette.secondary.opacity(0.15)
                                  : Color.clear)
                    )
                    .foregroundStyle(selected == tab
                                     ? Palette.secondary
                                     : Palette.onSurfaceVariant.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Palette.surfaceContainerLow)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.outlineVariant.opacity(0.15))
                .frame(height: 0.5)
        }
    }
}

// MARK: - MoneyText (tabular numbers + CLP formatting)
struct MoneyText: View {
    let value: Decimal
    var font: Font = Typography.money
    var signed: Bool = false
    var color: Color? = nil

    var body: some View {
        Text(signed ? Formatters.clpSigned(value) : Formatters.clp(value))
            .font(font)
            .foregroundStyle(color ?? defaultColor)
    }

    private var defaultColor: Color {
        if signed {
            if value > 0 { return Palette.secondary }
            if value < 0 { return Palette.error }
        }
        return Palette.primary
    }
}

// MARK: - GlassCard (tonal surface con "no-line")
struct GlassCard<Content: View>: View {
    var tone: Tone = .low
    @ViewBuilder var content: Content

    enum Tone { case lowest, low, normal, high }

    private var background: Color {
        switch tone {
        case .lowest:  return Palette.surfaceContainerLowest
        case .low:     return Palette.surfaceContainerLow
        case .normal:  return Palette.surfaceContainer
        case .high:    return Palette.surfaceContainerHigh
        }
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

// MARK: - SectionHeader
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Typography.labelSM)
                .tracking(1.4)
                .foregroundStyle(Palette.onSurfaceVariant)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
                    .font(Typography.labelXS)
                    .tracking(1)
                    .foregroundStyle(Palette.secondary)
            }
        }
    }
}

// MARK: - EmptyStateView
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.secondary.opacity(0.6))
            Text(title)
                .font(Typography.titleMD)
                .foregroundStyle(Palette.primary)
            Text(message)
                .font(Typography.bodyMD)
                .foregroundStyle(Palette.onSurfaceVariant)
                .multilineTextAlignment(.center)
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Typography.titleSM)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            LinearGradient(
                                colors: [Palette.primary, Palette.primaryContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ConfirmDialog (overlay inline de confirmación, reemplaza .confirmationDialog que no
// funciona bien dentro de MenuBarExtra)
struct ConfirmDialog: View {
    let title: String
    let message: String
    var confirmLabel: String = "Confirmar"
    var cancelLabel: String = "Cancelar"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }
            VStack(spacing: Spacing.md) {
                VStack(spacing: Spacing.xs) {
                    Text(title.uppercased())
                        .font(Typography.labelSM)
                        .tracking(1.4)
                        .foregroundStyle(Palette.error)
                    Text(message)
                        .font(Typography.bodyMD)
                        .foregroundStyle(Palette.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Spacing.sm) {
                    Button(action: onCancel) {
                        Text(cancelLabel.uppercased())
                            .font(Typography.labelMD)
                            .tracking(1.2)
                            .foregroundStyle(Palette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(Palette.surfaceContainerLowest)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(Palette.outlineVariant.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    Button(action: onConfirm) {
                        Text(confirmLabel.uppercased())
                            .font(Typography.labelMD)
                            .tracking(1.2)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(Palette.error)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .background(Palette.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Palette.outlineVariant.opacity(0.4), lineWidth: 1)
            )
            .shadow(radius: 24, y: 8)
            .padding(.horizontal, Spacing.lg)
        }
    }
}
