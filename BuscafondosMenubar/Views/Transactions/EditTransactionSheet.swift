import SwiftUI
import SwiftData

struct EditTransactionSheet: View {
    let tx: FundTransaction
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var context

    @State private var tipo: TransactionTipo = .aporte
    @State private var fecha: Date = Date()
    @State private var valorCuotaStr: String = ""
    @State private var cuotasStr: String = ""
    @State private var errorMessage: String?
    @State private var loaded = false

    private var valorCuota: Decimal {
        Decimal(string: valorCuotaStr.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var cuotasAbs: Decimal {
        Decimal(string: cuotasStr.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var montoCLP: Decimal { valorCuota * cuotasAbs }

    private var canSubmit: Bool {
        valorCuota > 0 && cuotasAbs > 0 && !rescateRompeHistoria()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                header
                tipoToggle
                HStack(spacing: Spacing.sm) {
                    datePickerField
                    navField
                }
                quotasField
                summaryCard
                saveButton
                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.labelSM)
                        .foregroundStyle(Palette.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.surface)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            tipo = tx.tipo
            fecha = tx.fecha
            valorCuotaStr = Self.navFormatter.string(from: tx.valorCuota as NSDecimalNumber) ?? ""
            let absCuotas = tx.cuotas < 0 ? -tx.cuotas : tx.cuotas
            cuotasStr = Formatters.cuotas.string(from: absCuotas as NSDecimalNumber) ?? ""
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Detalle")
                }
                .font(Typography.labelSM)
                .foregroundStyle(Palette.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Editar movimiento".uppercased())
                .font(Typography.labelXS)
                .tracking(2)
                .foregroundStyle(Palette.onSurfaceVariant)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
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
            TextField("0,00", text: $valorCuotaStr)
                .textFieldStyle(.plain)
                .font(Typography.moneySM)
                .foregroundStyle(Palette.primary)
                .tint(Palette.secondary)
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

    private var saveButton: some View {
        Button(action: save) {
            Text("Guardar cambios".uppercased())
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
    }

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

    // Simula el reemplazo de esta transacción con los nuevos valores y verifica
    // que el saldo de cuotas del fondo nunca se vuelva negativo en orden cronológico.
    private func rescateRompeHistoria() -> Bool {
        guard let fund = tx.fund else { return false }
        let nuevoSigned: Decimal = tipo == .aporte ? cuotasAbs : -cuotasAbs
        let nuevaFecha = Self.txCalendar.startOfDay(for: fecha)
        let txId = ObjectIdentifier(tx)
        var simuladas: [(fecha: Date, orden: Int, cuotas: Decimal)] = fund.transacciones.compactMap { existing in
            if ObjectIdentifier(existing) == txId { return nil }
            return (
                fecha: Self.txCalendar.startOfDay(for: existing.fecha),
                orden: 0,
                cuotas: existing.cuotas
            )
        }
        simuladas.append((fecha: nuevaFecha, orden: 1, cuotas: nuevoSigned))
        simuladas.sort { lhs, rhs in
            if lhs.fecha != rhs.fecha { return lhs.fecha < rhs.fecha }
            return lhs.orden < rhs.orden
        }
        var running: Decimal = 0
        for t in simuladas {
            running += t.cuotas
            if running < 0 { return true }
        }
        return false
    }

    private func save() {
        guard canSubmit else {
            errorMessage = "Ese rescate dejaría el saldo de cuotas en negativo."
            return
        }
        let signed: Decimal = tipo == .aporte ? cuotasAbs : -cuotasAbs
        tx.tipo = tipo
        tx.fecha = fecha
        tx.valorCuota = valorCuota
        tx.cuotas = signed
        tx.montoCLP = signed * valorCuota
        do {
            try context.save()
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
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
