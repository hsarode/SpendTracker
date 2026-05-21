import SwiftUI
import SwiftData

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]

    @State private var testInput: String = ""
    @State private var parseResult: String = ""
    @State private var notificationStatus: String = ""

    // Sample bank notification texts to test with
    let sampleTexts = [
        "Your Cr.Card XXX2944 was used for SAR38.00 on 19/05/2026 21:35:29 at HUNGERSTATION LLC,RIYADH-SA. Avl. Cr.limit is AED6943.79",
        """
        Credit Card Purchase
        Card Ending: 5034
        At: Amazon.ae, Dubai
        Amount: AED 88.00
        Date: 06/05/2026, 12:40
        Available Limit: AED 13,412.00
        """,
        "Your STC Pay account debited SAR 55.00 at CAREEM on 19/05/2026",
        "SABB: SAR 1,250.00 debited at TAMIMI MARKETS on 19/05/2026",
        "Riyad Bank: A purchase of SAR 89.00 was made at MCDONALDS on 19/05/2026"
    ]
    

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Device Token
                    if let token = UserDefaults.standard.string(forKey: "deviceToken") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device Token")
                                .font(.headline)
                            Text(token)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            Button("Copy Token") {
                                UIPasteboard.general.string = token
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }

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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Full Pipeline")
                            .font(.headline)
                        // Add this button temporarily under "Test Full Pipeline"
                        Button("Simulate Extension Save") {
                            simulateExtensionSave()
                        }
                        .buttonStyle(.borderedProminent)

                        Text("Fires a real local notification that goes through the Notification Extension — tests the complete flow end to end.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(sampleTexts, id: \.self) { sample in
                            Button {
                                fireTestNotification(body: sample)
                            } label: {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .font(.caption)
                                    Text("Fire: \(sample.prefix(40))...")
                                        .font(.caption)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .foregroundColor(.accentColor)
                        }

                        if !notificationStatus.isEmpty {
                            Text(notificationStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                currency: result.currency,
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
    private func fireTestNotification(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Bank Alert"
        content.body = body
        content.sound = .default

        // Fire after 5 seconds so you can background the app
        // Extension only intercepts when app is NOT in foreground
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    notificationStatus = "❌ Failed: \(error.localizedDescription)"
                } else {
                    notificationStatus = "⏱ Notification firing in 5 seconds — background the app now!"
                }
            }
        }
    }
    private func simulateExtensionSave() {
        let testText = "Al Rajhi Bank: Your account was debited SAR 125.50 at STARBUCKS RIYADH on 19/05/2026"

        guard let parsed = NotificationParser.parse(notificationBody: testText) else {
            print("❌ Parser failed")
            return
        }

        // Save directly using same App Group path the extension uses
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.harshal.spendtracker") else {
            print("❌ App Group not available — this is the problem")
            notificationStatus = "❌ App Group container not found. Check entitlements."
            return
        }

        print("✅ App Group URL: \(containerURL)")
        notificationStatus = "✅ App Group accessible at: \(containerURL.path)"

        let transaction = Transaction(
            amount: parsed.amount,
            currency: parsed.currency,
            merchant: parsed.merchant,
            category: parsed.category,
            date: parsed.date,
            rawNotificationText: testText,
            source: .bankPush
        )

        modelContext.insert(transaction)
        try? modelContext.save()
        print("✅ Transaction saved via simulate")
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
