import SwiftUI
import SwiftData

struct FundsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Fund.nombre) private var funds: [Fund]
    @State private var showAddSheet = false

    private var grouped: [(agf: String, funds: [Fund])] {
        let dict = Dictionary(grouping: funds, by: { $0.agf?.nombre ?? "Sin AGF" })
        return dict
            .map { (agf: $0.key, funds: $0.value.sorted { $0.nombre < $1.nombre }) }
            .sorted { $0.agf < $1.agf }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.surface.ignoresSafeArea()
            if showAddSheet {
                AddFundSheet(onDismiss: { showAddSheet = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        header
                        if funds.isEmpty {
                            EmptyStateView(
                                icon: "building.columns",
                                title: "Sin fondos todavía",
                                message: "Agrega un fondo para empezar a trackear tu portafolio.",
                                actionLabel: "Agregar fondo",
                                action: { showAddSheet = true }
                            )
                        } else {
                            ForEach(grouped, id: \.agf) { group in
                                agfSection(title: group.agf, funds: group.funds)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gestión de fondos".uppercased())
                    .font(Typography.labelXS)
                    .tracking(2)
                    .foregroundStyle(Palette.onSurfaceVariant)
                Text("\(funds.count) fondos")
                    .font(Typography.titleSM)
                    .foregroundStyle(Palette.primary)
            }
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus")
                    Text("Agregar")
                }
                .font(Typography.labelSM)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
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

    private func agfSection(title: String, funds: [Fund]) -> some View {
        GlassCard(tone: .low) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.secondary)
                        .frame(width: 3, height: 14)
                    Text(title.uppercased())
                        .font(Typography.labelSM)
                        .tracking(1.4)
                        .foregroundStyle(Palette.primary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(funds.count)".uppercased())
                        .font(Typography.labelXS)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
                VStack(spacing: Spacing.xs) {
                    ForEach(funds) { fund in
                        fundRow(fund)
                    }
                }
            }
        }
    }

    private func fundRow(_ fund: Fund) -> some View {
        let cuotas = fund.transacciones.reduce(Decimal(0)) { $0 + $1.cuotas }
        let valor = cuotas * fund.ultimoValorCuota
        return HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(fund.nombre)
                    .font(Typography.titleSM)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                Text("\(fund.run) · Serie \(fund.serie)".uppercased())
                    .font(Typography.labelXS)
                    .tracking(1)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.clp(valor))
                    .font(Typography.moneySM)
                    .foregroundStyle(Palette.primary)
                Text("\(Formatters.cuotas.string(from: cuotas as NSDecimalNumber) ?? "0") cuotas")
                    .font(Typography.labelXS)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
        }
        .padding(.vertical, 4)
    }
}
