import SwiftUI
import SwiftData

/// Monitors clipboard for bank SMS text when app becomes active
struct ClipboardMonitorView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var detectedText: String? = nil
    @State private var showBanner: Bool = false
    @State private var hasLaunched: Bool = false        // ← tracks first launch

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didBecomeActiveNotification
                    )
                ) { _ in
                    guard hasLaunched else {
                        // Skip clipboard check on very first launch
                        hasLaunched = true
                        return
                    }
                    checkClipboard()
                }

            if showBanner, let text = detectedText {
                ClipboardBanner(text: text) {
                    importFromClipboard(text)
                } onDismiss: {
                    withAnimation { showBanner = false }
                    detectedText = nil
                    UserDefaults.standard.set(
                        UIPasteboard.general.changeCount,
                        forKey: "lastClipboardCount"
                    )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    private func checkClipboard() {
        // Skip if app was opened via URL scheme (Shortcut triggered)
        if UserDefaults.standard.bool(forKey: "openedViaURL") {
            UserDefaults.standard.set(false, forKey: "openedViaURL")
            return
        }

        guard let text = UIPasteboard.general.string,
              !text.isEmpty else { return }

        // Ignore URL scheme strings
        guard !text.hasPrefix("spendtracker://") else { return }

        // Don't show same clipboard content twice
        let currentCount = UIPasteboard.general.changeCount
        let lastCount = UserDefaults.standard.integer(forKey: "lastClipboardCount")
        guard currentCount != lastCount else { return }

        guard looksLikeTransaction(text) else { return }

        detectedText = text
        withAnimation(.spring()) {
            showBanner = true
        }
    }

    private func looksLikeTransaction(_ text: String) -> Bool {
        let keywords = [
            "debited", "credited", "purchase", "payment",
            "SAR", "SR", "AED", "USD", "EUR", "GBP",
            "spent", "charged", "was used for", "used for",
            "تم الخصم", "تم الإيداع", "مدين", "دائن"
        ]
        return keywords.contains { text.lowercased().contains($0) }
    }

    private func importFromClipboard(_ text: String) {
        withAnimation { showBanner = false }

        UserDefaults.standard.set(
            UIPasteboard.general.changeCount,
            forKey: "lastClipboardCount"
        )

        guard let parsed = NotificationParser.parse(notificationBody: text) else {
            let transaction = Transaction(
                amount: 0.0,
                currency: "SAR",
                merchant: "Review Required",
                category: .uncategorized,
                date: .now,
                rawNotificationText: text,
                source: .sms
            )
            modelContext.insert(transaction)
            try? modelContext.save()
            return
        }

        let transaction = Transaction(
            amount: parsed.amount,
            currency: parsed.currency,
            merchant: parsed.merchant,
            category: parsed.category,
            date: parsed.date,
            rawNotificationText: text,
            source: .sms
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        print("✅ Imported from clipboard: \(parsed.merchant)")
    }
}


// MARK: - Banner UI
struct ClipboardBanner: View {
    let text: String
    let onImport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundColor(.accentColor)
                Text("Transaction Detected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                Button("Import Transaction") {
                    onImport()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)

                Button("Dismiss") {
                    onDismiss()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
