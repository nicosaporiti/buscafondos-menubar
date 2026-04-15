import SwiftUI
import SwiftData

struct TransactionFormView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var env: AppEnvironment
    @Query(sort: \Fund.nombre) private var funds: [Fund]

    @State private var tipo: TransactionTipo = .aporte
    @State private var selectedFundId: String? = nil
    @State private var fecha: Date = Date()
    @State private var valorCuotaStr: String = ""
    @State private var cuotasStr: String = ""
    @State private var fetchingNAV = false
    @State private var navTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var success = false

    private var selectedFund: Fund? {
        funds.first { $0.realAssetId == selectedFundId }
    }

    private var valorCuota: Decimal {
        Decimal(string: valorCuotaStr.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var cuotas: Decimal {
        Decimal(string: cuotasStr.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var montoCLP: Decimal { valorCuota * cuotas }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                headerEditorial
                if funds.isEmpty {
                    EmptyStateView(
                        icon: "plus.circle",
                        title: "Agrega un fondo primero",
                        message: "Necesitas al menos un fondo para registrar aportes."
                    )
                } else {
                    tipoToggle
                    fundPicker
                    HStack(spacing: Spacing.sm) {
                        datePickerField
                        navField
                    }
                    quotasField
                    summaryCard
                    submitButton
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.labelSM)
                            .foregroundStyle(Palette.error)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .onAppear {
            if selectedFundId == nil { selectedFundId = funds.first?.realAssetId }
        }
        .onChange(of: fecha) { _, _ in scheduleNAVFetch() }
        .onChange(of: selectedFundId) { _, _ in scheduleNAVFetch() }
    }

    // MARK: - Subviews

    private var headerEditorial: some View {
        VStack(spacing: 2) {
            Text("Registro de operación".uppercased())
                .font(Typography.labelXS)
                .tracking(2)
                .foregroundStyle(Palette.secondary)
            Text("Nueva transacción")
                .font(Typography.displayMD)
                .foregroundStyle(Palette.primary)
        }
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity)
    }

    private var tipoToggle: some View {
        HStack(spacing: 0) {
            ForEach(TransactionTipo.allCases) { t in
                Button {
                    tipo = t
                } label: {
                    Text(t.label.uppercased())
                        .font(Typography.labelSM)
                        .tracking(1.2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            tipo == t
                            ? Palette.surfaceContainerLowest
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .foregroundStyle(tipo == t ? Palette.primary : Palette.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var fundPicker: some View {
        field(label: "Fondo objetivo") {
            Menu {
                Picker("", selection: $selectedFundId) {
                    ForEach(funds) { fund in
                        Text(fund.nombre + " · " + fund.serie).tag(Optional(fund.realAssetId))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(selectedFund.map { "\($0.nombre) · \($0.serie)" } ?? "Selecciona un fondo")
                        .font(Typography.titleSM)
                        .foregroundStyle(Palette.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    private var datePickerField: some View {
        field(label: "Fecha efectiva") {
            DatePicker("", selection: $fecha, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Palette.secondary)
                .font(Typography.moneySM)
                .environment(\.colorScheme, .light)
        }
    }

    private var navField: some View {
        field(label: "Valor cuota (CLP)") {
            HStack {
                TextField("0,00", text: $valorCuotaStr)
                    .textFieldStyle(.plain)
                    .font(Typography.moneySM)
                    .foregroundStyle(Palette.primary)
                    .tint(Palette.secondary)
                if fetchingNAV {
                    ProgressView().controlSize(.mini)
                }
            }
        }
    }

    private var quotasField: some View {
        field(label: "Número de cuotas") {
            TextField("0,00", text: $cuotasStr)
                .textFieldStyle(.plain)
                .font(Typography.moneyMD)
                .foregroundStyle(Palette.primary)
                .tint(Palette.secondary)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monto estimado".uppercased())
                    .font(Typography.labelXS)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text(Formatters.clp(montoCLP))
                    .font(Typography.moneyMD)
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(tipo.label.uppercased())
                    .font(Typography.labelXS)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text(Formatters.shortDate.string(from: fecha))
                    .font(Typography.labelMD)
                    .foregroundStyle(.white)
            }
        }
        .padding(Spacing.md)
        .background(
            LinearGradient(
                colors: [Palette.primary, Palette.primaryContainer],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text((tipo == .aporte ? "Registrar aporte" : "Registrar rescate").uppercased())
                .font(Typography.labelMD)
                .tracking(1.2)
                .foregroundStyle(canSubmit ? Color.white : Palette.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background {
                    if canSubmit {
                        LinearGradient(
                            colors: [Palette.secondary, Palette.primaryContainer],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Palette.surfaceContainerHigh
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .overlay(alignment: .top) {
            if success {
                Text("Guardado").font(Typography.labelSM).foregroundStyle(Palette.secondary).offset(y: -16)
            }
        }
    }

    // MARK: - Helpers

    private func field<Content: View>(label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Typography.labelXS)
                .tracking(1.4)
                .foregroundStyle(Palette.onSurfaceVariant)
            content()
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surfaceContainerLowest)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Palette.outlineVariant.opacity(0.35), lineWidth: 1)
                )
        }
    }

    private static let txCalendar = Calendar(identifier: .gregorian)

    private func cuotasDisponibles(at date: Date) -> Decimal {
        guard let fund = selectedFund else { return 0 }
        let day = Self.txCalendar.startOfDay(for: date)
        return fund.transacciones
            .filter { Self.txCalendar.startOfDay(for: $0.fecha) <= day }
            .reduce(Decimal(0)) { $0 + $1.cuotas }
    }

    // Simula insertar un rescate en `fecha` por `cuotas` y verifica que el saldo
    // nunca se vuelva negativo. Las fechas se comparan a nivel de día calendario
    // para que dos operaciones del mismo día visible se validen de forma estable.
    private func rescateRompeHistoria() -> Bool {
        guard tipo == .rescate, cuotas > 0, let fund = selectedFund else { return false }
        let nuevaFecha = Self.txCalendar.startOfDay(for: fecha)
        // orden = 0 para operaciones existentes, 1 para el rescate simulado, de modo
        // que el nuevo rescate siempre se evalúe después de todas las operaciones del
        // mismo día calendario, sin depender de la estabilidad del sort.
        var simuladas: [(fecha: Date, orden: Int, cuotas: Decimal)] = fund.transacciones.map {
            (fecha: Self.txCalendar.startOfDay(for: $0.fecha), orden: 0, cuotas: $0.cuotas)
        }
        simuladas.append((fecha: nuevaFecha, orden: 1, cuotas: -cuotas))
        simuladas.sort { lhs, rhs in
            if lhs.fecha != rhs.fecha { return lhs.fecha < rhs.fecha }
            return lhs.orden < rhs.orden
        }
        var running: Decimal = 0
        for tx in simuladas {
            running += tx.cuotas
            if running < 0 { return true }
        }
        return false
    }

    private var canSubmit: Bool {
        selectedFund != nil && valorCuota > 0 && cuotas > 0 && !rescateRompeHistoria()
    }

    private func submit() {
        guard let fund = selectedFund else { return }
        if rescateRompeHistoria() {
            let disponibles = cuotasDisponibles(at: fecha)
            errorMessage = "En esa fecha solo tenías \(Formatters.cuotas.string(from: disponibles as NSDecimalNumber) ?? "0") cuotas disponibles."
            return
        }
        let tx = FundTransaction(
            fecha: fecha,
            tipo: tipo,
            valorCuota: valorCuota,
            cuotas: cuotas,
            fund: fund
        )
        context.insert(tx)
        do {
            try context.save()
            success = true
            cuotasStr = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { success = false }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleNAVFetch() {
        navTask?.cancel()
        guard let fund = selectedFund else { return }
        let requestFundId = fund.realAssetId
        let requestFecha = fecha
        fetchingNAV = true
        navTask = Task {
            defer {
                if selectedFundId == requestFundId && fecha == requestFecha {
                    fetchingNAV = false
                }
            }
            let cal = Calendar(identifier: .gregorian)
            let day = cal.startOfDay(for: requestFecha)
            let from = cal.date(byAdding: .day, value: -7, to: day) ?? day
            do {
                let history = try await env.api.priceHistory(
                    realAssetId: requestFundId,
                    from: from,
                    to: day
                )
                if Task.isCancelled { return }
                guard selectedFundId == requestFundId && fecha == requestFecha else { return }
                guard let point = history.last(where: { $0.date <= day }) ?? history.last else {
                    errorMessage = "No hay valor cuota disponible cerca de esa fecha."
                    return
                }
                errorMessage = nil
                valorCuotaStr = Self.navFormatter.string(from: point.price as NSDecimalNumber) ?? "\((point.price as NSDecimalNumber).doubleValue)"
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                guard selectedFundId == requestFundId && fecha == requestFecha else { return }
                errorMessage = "No se pudo obtener el valor cuota: \(error.localizedDescription)"
            }
        }
    }

    private static let navFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = false
        return f
    }()
}
