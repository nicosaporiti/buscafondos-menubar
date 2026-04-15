import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var env: AppEnvironment
    @Query private var funds: [Fund]

    private var snapshot: PortfolioSnapshot {
        env.calculator.snapshot(from: funds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                heroBalance
                performanceBento
                topPositions
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - Hero

    private var heroBalance: some View {
        VStack(spacing: Spacing.xs) {
            Text("Saldo del portafolio".uppercased())
                .font(Typography.labelXS)
                .tracking(2)
                .foregroundStyle(Palette.onSurfaceVariant)

            Text(Formatters.clp(snapshot.total))
                .font(Typography.moneyLG)
                .foregroundStyle(Palette.primary)
                .contentTransition(.numericText())

            HStack(spacing: Spacing.xs) {
                Image(systemName: snapshot.retornoAbs >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(Formatters.percent(snapshot.retornoPct))
                    .font(Typography.moneySM)
                Text(Formatters.clpSigned(snapshot.retornoAbs))
                    .font(Typography.moneySM)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            .foregroundStyle(snapshot.retornoAbs >= 0 ? Palette.secondary : Palette.error)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Palette.secondaryContainer.opacity(0.15))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Performance bento grid

    private var performanceBento: some View {
        GlassCard(tone: .low) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "Rendimiento", trailing: "CLP")
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Spacing.sm),
                    GridItem(.flexible(), spacing: Spacing.sm),
                ], spacing: Spacing.sm) {
                    bentoCell(title: "Hoy",        value: snapshot.today,      bars: [0.5, 0.75, 1.0])
                    bentoCell(title: "MTD",        value: snapshot.mtd,        bars: [0.25, 0.66, 1.0])
                    bentoCell(title: "Mes pasado", value: snapshot.lastMonth,  bars: [1.0, 0.66, 0.33])
                    bentoCell(title: "YTD",        value: snapshot.ytd,        bars: [0.25, 0.5, 1.0])
                }
            }
        }
    }

    private func bentoCell(title: String, value: Decimal, bars: [CGFloat]) -> some View {
        let positive = value >= 0
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(Typography.labelXS)
                .tracking(1)
                .foregroundStyle(Palette.onSurfaceVariant)
            Text(Formatters.clpSigned(value))
                .font(Typography.moneySM)
                .foregroundStyle(positive ? Palette.primary : Palette.error)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { (idx, h) in
                    RoundedRectangle(cornerRadius: 1)
                        .fill((positive ? Palette.secondary : Palette.error)
                              .opacity(idx == bars.count - 1 ? 1 : 0.3))
                        .frame(height: 18 * h)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 20)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Top positions

    private var topPositions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Posiciones")
            if snapshot.holdings.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "Sin posiciones aún",
                    message: "Agrega un fondo y registra tu primer aporte."
                )
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: Spacing.md) {
                    ForEach(snapshot.holdings.prefix(5)) { holding in
                        positionRow(holding)
                    }
                }
            }
        }
    }

    private func positionRow(_ h: Holding) -> some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Palette.primaryContainer)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(h.nombre.prefix(2)).uppercased())
                        .font(Typography.labelSM)
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(h.nombre)
                    .font(Typography.titleSM)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                Text(h.agfNombre.uppercased())
                    .font(Typography.labelXS)
                    .tracking(1)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.clp(h.valorActual))
                    .font(Typography.moneySM)
                    .foregroundStyle(Palette.primary)
                Text(Formatters.percent(h.retornoPct))
                    .font(Typography.labelXS)
                    .foregroundStyle(h.retornoAbs >= 0 ? Palette.secondary : Palette.error)
            }
        }
    }
}
