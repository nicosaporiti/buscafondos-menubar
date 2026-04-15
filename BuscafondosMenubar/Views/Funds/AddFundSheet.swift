import SwiftUI
import SwiftData

struct AddFundSheet: View {
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var context
    @EnvironmentObject var env: AppEnvironment

    @State private var query: String = ""
    @State private var items: [AllFundItem] = []
    @State private var loading = false
    @State private var errorMessage: String?

    private var filtered: [AllFundItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Array(items.prefix(40)) }
        return items
            .filter { $0.fundName.lowercased().contains(q)
                   || $0.agf.lowercased().contains(q)
                   || $0.run.lowercased().contains(q) }
            .prefix(60)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            header
            searchBar
            list
        }
        .padding(.top, Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.surface)
        .task {
            if items.isEmpty { await loadCatalog() }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Fondos")
                }
                .font(Typography.labelSM)
                .foregroundStyle(Palette.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Agregar fondo".uppercased())
                .font(Typography.labelXS)
                .tracking(2)
                .foregroundStyle(Palette.onSurfaceVariant)
            Spacer()
            Color.clear.frame(width: 50, height: 1)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.onSurfaceVariant)
                .font(.system(size: 12, weight: .semibold))
            TextField("", text: $query, prompt:
                Text("Buscar por nombre, AGF o RUN…")
                    .foregroundStyle(Palette.onSurfaceVariant.opacity(0.9))
            )
            .textFieldStyle(.plain)
            .font(Typography.bodyMD)
            .foregroundStyle(Palette.primary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Palette.surfaceContainerHighest)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Spacing.md)
    }

    @ViewBuilder
    private var list: some View {
        if loading && items.isEmpty {
            VStack(spacing: Spacing.sm) {
                ProgressView()
                    .controlSize(.small)
                Text("Descargando catálogo CMF…")
                    .font(Typography.labelMD)
                    .foregroundStyle(Palette.primary)
                Text("~1 MB · ~2.900 series · primera vez ~7 s. Luego se cachea 24 h.")
                    .font(Typography.labelXS)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.error)
                Text(errorMessage).font(Typography.bodyMD)
                Button("Reintentar") { Task { await loadCatalog() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        Button {
                            addFund(item)
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func row(_ item: AllFundItem) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fundName)
                    .font(Typography.titleSM)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                Text("\(item.agf) · \(item.serie) · \(item.run)")
                    .font(Typography.labelXS)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
                if let tac = item.tac {
                    Text("TAC \(String(format: "%.2f%%", tac * 100))")
                        .font(Typography.labelXS)
                        .foregroundStyle(Palette.secondary)
                }
                if let dc = item.dailyChange {
                    Text(String(format: "%+.2f%%", dc))
                        .font(Typography.labelXS)
                        .monospacedDigit()
                        .foregroundStyle(dc >= 0 ? Palette.secondary : Palette.error)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.surfaceContainerHigh)
                .frame(height: 0.5)
        }
    }

    // MARK: - Actions

    private func loadCatalog() async {
        loading = true
        defer { loading = false }
        do {
            items = try await env.api.allFunds()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFund(_ item: AllFundItem) {
        let providerId = "agf:\(item.agf)"
        let agf: AGF
        if let existing = try? context.fetch(FetchDescriptor<AGF>(predicate: #Predicate { $0.providerId == providerId })).first {
            agf = existing
        } else {
            agf = AGF(providerId: providerId, nombre: item.agf)
            context.insert(agf)
        }

        let assetId = item.serieId
        let existingFund = try? context.fetch(FetchDescriptor<Fund>(predicate: #Predicate { $0.realAssetId == assetId })).first
        if existingFund == nil {
            let fund = Fund(
                realAssetId: item.serieId,
                conceptId: item.fundId,
                run: item.run,
                nombre: item.fundName,
                serie: item.serie,
                categoria: item.category,
                tacAnual: item.tac.map { Decimal($0) },
                agf: agf
            )
            context.insert(fund)
            Task {
                if let latest = try? await env.api.latestPrice(realAssetId: item.serieId) {
                    fund.ultimoValorCuota = latest.price
                    fund.ultimoValorCuotaFecha = latest.date
                    try? context.save()
                }
            }
        }
        try? context.save()
        onDismiss()
    }
}
