import SwiftUI
import SwiftData

struct FundDetailSheet: View {
    let fund: Fund
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var context

    @State private var editingTx: FundTransaction?
    @State private var showDeleteFundConfirm = false
    @State private var txPendingDelete: FundTransaction?
    @State private var deleteBlockedMessage: String?

    private static let txCalendar = Calendar(identifier: .gregorian)

    private var sortedTransacciones: [FundTransaction] {
        fund.transacciones.sorted { $0.fecha > $1.fecha }
    }

    private var cuotasTotales: Decimal {
        fund.transacciones.reduce(Decimal(0)) { $0 + $1.cuotas }
    }

    private var valorEstimado: Decimal {
        cuotasTotales * fund.ultimoValorCuota
    }

    var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()
            if let editingTx {
                EditTransactionSheet(tx: editingTx) {
                    self.editingTx = nil
                }
            } else {
                content
            }
            if showDeleteFundConfirm {
                ConfirmDialog(
                    title: "Eliminar fondo",
                    message: "Se eliminará \"\(fund.nombre)\" junto con sus \(fund.transacciones.count) movimientos. Esta acción no se puede deshacer.",
                    confirmLabel: "Eliminar",
                    onConfirm: {
                        showDeleteFundConfirm = false
                        deleteFund()
                    },
                    onCancel: { showDeleteFundConfirm = false }
                )
            } else if let tx = txPendingDelete {
                ConfirmDialog(
                    title: "Eliminar movimiento",
                    message: "El movimiento del \(Formatters.shortDate.string(from: tx.fecha)) se eliminará permanentemente.",
                    confirmLabel: "Eliminar",
                    onConfirm: {
                        deleteTransaction(tx)
                        txPendingDelete = nil
                    },
                    onCancel: { txPendingDelete = nil }
                )
            } else if let message = deleteBlockedMessage {
                ConfirmDialog(
                    title: "No se puede eliminar",
                    message: message,
                    confirmLabel: "Entendido",
                    cancelLabel: "Cerrar",
                    onConfirm: { deleteBlockedMessage = nil },
                    onCancel: { deleteBlockedMessage = nil }
                )
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                headerCard
                summaryCard
                movimientosSection
                deleteFundButton
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
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
            Text("Detalle del fondo".uppercased())
                .font(Typography.labelXS)
                .tracking(2)
                .foregroundStyle(Palette.onSurfaceVariant)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
    }

    private var headerCard: some View {
        GlassCard(tone: .low) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text((fund.agf?.nombre ?? "Sin AGF").uppercased())
                    .font(Typography.labelXS)
                    .tracking(1.4)
                    .foregroundStyle(Palette.secondary)
                Text(fund.nombre)
                    .font(Typography.titleMD)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(2)
                Text("\(fund.run) · Serie \(fund.serie)".uppercased())
                    .font(Typography.labelXS)
                    .tracking(1)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
        }
    }

    private var summaryCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Valor estimado".uppercased())
                    .font(Typography.labelXS)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text(Formatters.clp(valorEstimado))
                    .font(Typography.moneyMD)
                    .foregroundStyle(.white)
                Text("\(Formatters.cuotas.string(from: cuotasTotales as NSDecimalNumber) ?? "0") cuotas")
                    .font(Typography.labelXS)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Último VC".uppercased())
                    .font(Typography.labelXS)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text(Formatters.cuotas.string(from: fund.ultimoValorCuota as NSDecimalNumber) ?? "—")
                    .font(Typography.moneySM)
                    .foregroundStyle(.white)
                Text(Formatters.shortDate.string(from: fund.ultimoValorCuotaFecha))
                    .font(Typography.labelXS)
                    .foregroundStyle(.white.opacity(0.6))
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

    private var movimientosSection: some View {
        GlassCard(tone: .low) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.secondary)
                        .frame(width: 3, height: 14)
                    Text("Movimientos".uppercased())
                        .font(Typography.labelSM)
                        .tracking(1.4)
                        .foregroundStyle(Palette.primary)
                    Spacer()
                    Text("\(fund.transacciones.count)")
                        .font(Typography.labelXS)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
                if fund.transacciones.isEmpty {
                    Text("Sin movimientos registrados")
                        .font(Typography.labelSM)
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .padding(.vertical, Spacing.sm)
                } else {
                    VStack(spacing: 0) {
                        ForEach(sortedTransacciones) { tx in
                            transaccionRow(tx)
                        }
                    }
                }
            }
        }
    }

    private func transaccionRow(_ tx: FundTransaction) -> some View {
        let isAporte = tx.tipo == .aporte
        let absCuotas = tx.cuotas < 0 ? -tx.cuotas : tx.cuotas
        return Button {
            editingTx = tx
        } label: {
            HStack(alignment: .center, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(tx.tipo.label.uppercased())
                            .font(Typography.labelXS)
                            .tracking(1.2)
                            .foregroundStyle(isAporte ? Palette.secondary : Palette.error)
                        Text("·")
                            .foregroundStyle(Palette.onSurfaceVariant)
                        Text(Formatters.shortDate.string(from: tx.fecha))
                            .font(Typography.labelXS)
                            .foregroundStyle(Palette.onSurfaceVariant)
                    }
                    Text("\(Formatters.cuotas.string(from: absCuotas as NSDecimalNumber) ?? "0") cuotas @ \(Formatters.cuotas.string(from: tx.valorCuota as NSDecimalNumber) ?? "—")")
                        .font(Typography.labelXS)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
                Spacer()
                Text(Formatters.clp(absCuotas * tx.valorCuota))
                    .font(Typography.moneySM)
                    .foregroundStyle(isAporte ? Palette.primary : Palette.error)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Palette.surfaceContainerHigh)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingTx = tx
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            Button(role: .destructive) {
                requestDelete(tx)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    private var deleteFundButton: some View {
        Button {
            showDeleteFundConfirm = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "trash")
                Text("Eliminar fondo".uppercased())
                    .tracking(1.2)
            }
            .font(Typography.labelMD)
            .foregroundStyle(Palette.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Palette.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.error.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, Spacing.sm)
    }

    private func requestDelete(_ tx: FundTransaction) {
        if let reason = deletionBreaksHistory(tx) {
            deleteBlockedMessage = reason
        } else {
            txPendingDelete = tx
        }
    }

    // Simula eliminar `tx` y verifica que el saldo de cuotas nunca quede
    // negativo en orden cronológico. Devuelve un mensaje si el borrado rompe
    // un rescate posterior, nil si es seguro.
    private func deletionBreaksHistory(_ tx: FundTransaction) -> String? {
        let txId = ObjectIdentifier(tx)
        let simuladas = fund.transacciones
            .compactMap { existing -> (fecha: Date, cuotas: Decimal)? in
                if ObjectIdentifier(existing) == txId { return nil }
                return (Self.txCalendar.startOfDay(for: existing.fecha), existing.cuotas)
            }
            .sorted { $0.fecha < $1.fecha }
        var running: Decimal = 0
        for t in simuladas {
            running += t.cuotas
            if running < 0 {
                return "Si eliminas este aporte, un rescate posterior del \(Formatters.shortDate.string(from: t.fecha)) queda sin saldo suficiente. Edita o elimina primero el rescate."
            }
        }
        return nil
    }

    private func deleteTransaction(_ tx: FundTransaction) {
        context.delete(tx)
        try? context.save()
    }

    private func deleteFund() {
        context.delete(fund)
        try? context.save()
        onDismiss()
    }
}
