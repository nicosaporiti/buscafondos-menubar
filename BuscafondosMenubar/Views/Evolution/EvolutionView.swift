import SwiftUI
import SwiftData
import Charts

enum Timeframe: String, CaseIterable, Identifiable {
    case m1 = "1M"
    case m3 = "3M"
    case m6 = "6M"
    case y1 = "1Y"
    case all = "ALL"
    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .m1: return 30
        case .m3: return 90
        case .m6: return 180
        case .y1: return 365
        case .all: return nil
        }
    }
}

struct EvolutionView: View {
    @EnvironmentObject var env: AppEnvironment
    @Query private var funds: [Fund]

    @State private var timeframe: Timeframe = .y1
    @State private var series: [SeriesPoint] = []
    @State private var loading = false

    struct SeriesPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Decimal
        var displayValue: Double { (value as NSDecimalNumber).doubleValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                timeframeSelector
                chartCard
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .task(id: reloadKey) { await loadSeries() }
    }

    private var reloadKey: String {
        let fundsSig = funds
            .map { "\($0.realAssetId):\($0.transacciones.count):\($0.ultimoValorCuota)" }
            .sorted()
            .joined(separator: "|")
        return "\(timeframe.rawValue)#\(fundsSig)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Evolución de retornos".uppercased())
                .font(Typography.labelXS)
                .tracking(2)
                .foregroundStyle(Palette.onSurfaceVariant)
            Text(Formatters.clp(series.last?.value ?? 0))
                .font(Typography.moneyLG)
                .foregroundStyle(Palette.primary)
        }
    }

    private var timeframeSelector: some View {
        HStack(spacing: 4) {
            ForEach(Timeframe.allCases) { tf in
                Button {
                    timeframe = tf
                } label: {
                    Text(tf.rawValue)
                        .font(Typography.labelSM)
                        .tracking(1)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background(
                            timeframe == tf
                            ? Palette.surfaceContainerLowest
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .foregroundStyle(timeframe == tf ? Palette.secondary : Palette.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private var chartCard: some View {
        GlassCard(tone: .lowest) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if loading {
                    ProgressView("Calculando…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if series.isEmpty {
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "Sin historial",
                        message: "Agrega fondos y aportes para ver la evolución."
                    )
                } else {
                    Chart(series) { point in
                        AreaMark(
                            x: .value("Fecha", point.date),
                            y: .value("Valor", point.displayValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Palette.secondary.opacity(0.25), Palette.secondary.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                        LineMark(
                            x: .value("Fecha", point.date),
                            y: .value("Valor", point.displayValue)
                        )
                        .foregroundStyle(Palette.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.monotone)
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing) { _ in
                            AxisValueLabel()
                                .font(Typography.labelXS)
                                .foregroundStyle(Palette.onSurfaceVariant)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                                .font(Typography.labelXS)
                                .foregroundStyle(Palette.onSurfaceVariant)
                        }
                    }
                    .frame(height: 220)
                }
            }
        }
    }

    // MARK: - Data

    private func loadSeries() async {
        loading = true
        defer { loading = false }
        guard !funds.isEmpty else { series = []; return }

        let to = Date()
        let from: Date? = timeframe.days.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: to) ?? to
        }

        // Fetch per-fund price histories in parallel.
        var byFund: [String: [PricePoint]] = [:]
        await withTaskGroup(of: (String, [PricePoint]).self) { group in
            for fund in funds {
                group.addTask {
                    let points = (try? await env.api.priceHistory(
                        realAssetId: fund.realAssetId,
                        from: from,
                        to: to
                    )) ?? []
                    return (fund.realAssetId, points)
                }
            }
            for await (id, points) in group {
                byFund[id] = points
            }
        }

        // Build a sorted union of all dates and compute Σ (cuotas_netas_a_t * nav_t) per date.
        let allDates = Set(byFund.values.flatMap { $0.map { $0.date } }).sorted()
        guard !allDates.isEmpty else { series = []; return }

        let cal = Calendar(identifier: .gregorian)
        var out: [SeriesPoint] = []
        for date in allDates {
            var total: Decimal = 0
            for fund in funds {
                let cuotasAtDate = fund.transacciones
                    .filter { cal.startOfDay(for: $0.fecha) <= date }
                    .reduce(Decimal(0)) { $0 + $1.cuotas }
                guard cuotasAtDate != 0 else { continue }
                let history = byFund[fund.realAssetId] ?? []
                let nav = lastPrice(in: history, upTo: date) ?? fund.ultimoValorCuota
                total += cuotasAtDate * nav
            }
            if total > 0 {
                out.append(SeriesPoint(date: date, value: total))
            }
        }
        series = out
    }

    private func lastPrice(in history: [PricePoint], upTo date: Date) -> Decimal? {
        var result: Decimal?
        for p in history {
            if p.date <= date { result = p.price } else { break }
        }
        return result
    }
}
