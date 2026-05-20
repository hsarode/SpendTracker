import SwiftUI
import SwiftData

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]

    @State private var testInput: String = ""
    @State private var parseResult: String = ""

    // Sample bank notification texts to test with
    let sampleTexts = [
        "Al Rajhi Bank: Your account was debited SAR 125.50 at STARBUCKS RIYADH on 19/05/2026",
        "SNB Alert: Purchase of SAR 450.00 at NOON.COM on 19/05/2026",
        "Your STC Pay account debited SAR 55.00 at CAREEM on 19/05/2026",
        "SABB: SAR 1,250.00 debited at TAMIMI MARKETS on 19/05/2026",
        "Riyad Bank: A purchase of SAR 89.00 was made at MCDONALDS on 19/05/2026"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Manual Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Notification Text")
                            .font(.headline)

                        TextEditor(text: $testInput)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                        Button("Parse") {
                            runParser(on: testInput)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(testInput.isEmpty)
                    }

                    // MARK: - Parse Result
                    if !parseResult.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Parse Result")
                                .font(.headline)
                            Text(parseResult)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }

                    // MARK: - Sample Texts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sample Bank Notifications")
                            .font(.headline)

                        ForEach(sampleTexts, id: \.self) { sample in
                            Button {
                                testInput = sample
                                runParser(on: sample)
                            } label: {
                                Text(sample)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    // MARK: - Saved Transactions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Saved Transactions (\(transactions.count))")
                                .font(.headline)
                            Spacer()
                            if !transactions.isEmpty {
                                Button("Clear All", role: .destructive) {
                                    clearAll()
                                }
                                .font(.caption)
                            }
                        }

                        if transactions.isEmpty {
                            Text("No transactions saved yet. Parse one above to save it.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(transactions) { transaction in
                                TransactionDebugRow(transaction: transaction)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Parser Debug")
        }
    }

    // MARK: - Actions
    private func runParser(on text: String) {
        if let result = NotificationParser.parse(notificationBody: text) {
            parseResult = """
            ✅ PARSED SUCCESSFULLY
            ──────────────────────
            Amount:   SAR \(result.amount)
            Merchant: \(result.merchant)
            Category: \(result.category.rawValue)
            Date:     \(result.date.formatted(date: .abbreviated, time: .omitted))
            """

            // Also save it to SwiftData so we can test persistence
            let transaction = Transaction(
                amount: result.amount,
                merchant: result.merchant,
                category: result.category,
                date: result.date,
                rawNotificationText: text,
                source: .bankPush
            )
            modelContext.insert(transaction)
            try? modelContext.save()

        } else {
            parseResult = """
            ❌ PARSE FAILED
            ──────────────────────
            No amount found in text.
            Try a different format.
            """
        }
    }

    private func clearAll() {
        transactions.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Debug Row
struct TransactionDebugRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            Image(systemName: transaction.category.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(transaction.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SAR \(transaction.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    DebugView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
