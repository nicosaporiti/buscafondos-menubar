import SwiftUI
import SwiftData

struct DashboardView: View {
    @EnvironmentObject var env: AppEnvironment
    @Query private var funds: [Fund]

    struct PeriodDelta: Equatable {
        var abs: Decimal
        var pct: Double
        var loaded: Bool
    }

    @State private var today = PeriodDelta(abs: 0, pct: 0, loaded: false)
    @State private var mtd = PeriodDelta(abs: 0, pct: 0, loaded: false)
    @State private var lastMonth = PeriodDelta(abs: 0, pct: 0, loaded: false)
    @State private var ytd = PeriodDelta(abs: 0, pct: 0, loaded: false)

    private var snapshot: PortfolioSnapshot {
        env.calculator.snapshot(from: funds)
    }

    private var periodsReloadKey: String {
        funds
            .map { fund -> String in
                let txsSig = fund.transacciones
                    .map { "\(Int($0.fecha.timeIntervalSince1970))/\($0.cuotas)/\($0.valorCuota)/\($0.tipoRaw)" }
                    .sorted()
                    .joined(separator: ";")
                return "\(fund.realAssetId):\(fund.ultimoValorCuota):\(txsSig)"
            }
            .sorted()
            .joined(separator: "|")
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
        .task(id: periodsReloadKey) { await loadPeriodDeltas() }
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
                    bentoCell(title: "Hoy",        delta: today)
                    bentoCell(title: "MTD",        delta: mtd)
                    bentoCell(title: "Mes pasado", delta: lastMonth)
                    bentoCell(title: "YTD",        delta: ytd)
                }
            }
        }
    }

    private func bentoCell(title: String, delta: PeriodDelta) -> some View {
        let positive = delta.abs >= 0
        let accent = positive ? Palette.secondary : Palette.error
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(Typography.labelXS)
                .tracking(1)
                .foregroundStyle(Palette.onSurfaceVariant)
            if delta.loaded {
                Text(Formatters.clpSigned(delta.abs))
                    .font(Typography.moneySM)
                    .foregroundStyle(Palette.primary)
                HStack(spacing: 4) {
                    Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(Formatters.percent(delta.pct))
                        .font(Typography.labelSM)
                }
                .foregroundStyle(accent)
            } else {
                Text("—")
                    .font(Typography.moneySM)
                    .foregroundStyle(Palette.onSurfaceVariant)
                Text("Calculando…")
                    .font(Typography.labelXS)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Period deltas

    private func loadPeriodDeltas() async {
        guard !funds.isEmpty else {
            today = PeriodDelta(abs: 0, pct: 0, loaded: true)
            mtd = PeriodDelta(abs: 0, pct: 0, loaded: true)
            lastMonth = PeriodDelta(abs: 0, pct: 0, loaded: true)
            ytd = PeriodDelta(abs: 0, pct: 0, loaded: true)
            return
        }

        let cal = Calendar(identifier: .gregorian)
        let endDay = cal.startOfDay(for: Date())

        // Reference dates (start of each period → day to value at market close).
        let yesterday = cal.date(byAdding: .day, value: -1, to: endDay) ?? endDay
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: endDay)) ?? endDay
        let endOfPrevMonth = cal.date(byAdding: .day, value: -1, to: startOfMonth) ?? startOfMonth
        let startOfPrevMonth = cal.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
        let endOfTwoMonthsAgo = cal.date(byAdding: .day, value: -1, to: startOfPrevMonth) ?? startOfPrevMonth
        let startOfYear = cal.date(from: cal.dateComponents([.year], from: endDay)) ?? endDay
        let endOfPrevYear = cal.date(byAdding: .day, value: -1, to: startOfYear) ?? startOfYear

        let refDates = [yesterday, endOfPrevMonth, endOfTwoMonthsAgo, endOfPrevYear]
        guard let minRef = refDates.min() else { return }
        let fetchFrom = cal.date(byAdding: .day, value: -14, to: minRef) ?? minRef

        // Fetch per-fund price histories in parallel.
        var byFund: [String: [PricePoint]] = [:]
        await withTaskGroup(of: (String, [PricePoint]).self) { group in
            for fund in funds {
                let id = fund.realAssetId
                group.addTask {
                    let pts = (try? await env.api.priceHistory(
                        realAssetId: id,
                        from: fetchFrom,
                        to: endDay
                    )) ?? []
                    return (id, pts.sorted { $0.date < $1.date })
                }
            }
            for await (id, pts) in group { byFund[id] = pts }
        }

        // Precompute sorted tx per fund.
        struct TxDay { let day: Date; let cuotas: Decimal; let valorCuota: Decimal }
        var txByFund: [String: [TxDay]] = [:]
        for fund in funds {
            txByFund[fund.realAssetId] = fund.transacciones
                .map { TxDay(day: cal.startOfDay(for: $0.fecha), cuotas: $0.cuotas, valorCuota: $0.valorCuota) }
                .sorted { $0.day < $1.day }
        }

        // Portfolio value at a given day using forward-fill NAV per fund.
        func valueAt(_ day: Date) -> Decimal {
            var total: Decimal = 0
            for fund in funds {
                let txs = txByFund[fund.realAssetId] ?? []
                var cuotas: Decimal = 0
                for tx in txs {
                    if tx.day <= day { cuotas += tx.cuotas } else { break }
                }
                guard cuotas > 0 else { continue }
                let history = byFund[fund.realAssetId] ?? []
                guard let nav = lastPrice(in: history, upTo: day) else { continue }
                total += cuotas * nav
            }
            return total
        }

        // Net cash flow (aportes − rescates) in (start, end] valuados a su valor cuota.
        func netCashIn(after start: Date, through end: Date) -> Decimal {
            var sum: Decimal = 0
            for fund in funds {
                let txs = txByFund[fund.realAssetId] ?? []
                for tx in txs where tx.day > start && tx.day <= end {
                    sum += tx.cuotas * tx.valorCuota
                }
            }
            return sum
        }

        func gain(from start: Date, to end: Date) -> PeriodDelta {
            let vStart = valueAt(start)
            let vEnd = valueAt(end)
            let cash = netCashIn(after: start, through: end)
            let delta = vEnd - vStart - cash
            let base = vStart
            let pct: Double = {
                guard base > 0 else { return 0 }
                return ((delta as NSDecimalNumber).doubleValue) / ((base as NSDecimalNumber).doubleValue)
            }()
            return PeriodDelta(abs: delta, pct: pct, loaded: true)
        }

        let t = gain(from: yesterday, to: endDay)
        let m = gain(from: endOfPrevMonth, to: endDay)
        let lm = gain(from: endOfTwoMonthsAgo, to: endOfPrevMonth)
        let y = gain(from: endOfPrevYear, to: endDay)

        await MainActor.run {
            today = t
            mtd = m
            lastMonth = lm
            ytd = y
        }
    }

    private func lastPrice(in history: [PricePoint], upTo date: Date) -> Decimal? {
        var result: Decimal?
        for p in history {
            if p.date <= date { result = p.price } else { break }
        }
        return result
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
