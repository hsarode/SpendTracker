import UserNotifications
import SwiftData

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let appGroupID = "group.com.harshal.spendtracker"

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            print("❌ Extension: Could not get mutable content")
            contentHandler(request.content)
            return
        }

        let fullText = "\(content.title) \(content.body)"
        print("🔔 Extension received: \(fullText)")

        if let parsed = NotificationParser.parse(notificationBody: fullText) {
            print("✅ Extension parsed: \(parsed.merchant) - \(parsed.amount)")
            saveTransaction(parsed, rawText: fullText)
        } else {
            print("❌ Extension: Parser returned nil for text: \(fullText)")
        }

        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        print("⚠️ Extension: time expired")
        if let contentHandler, let content = bestAttemptContent {
            contentHandler(content)
        }
    }

    private func saveTransaction(_ parsed: ParsedTransaction, rawText: String) {
        print("💾 Extension: attempting to save transaction")

        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("❌ Extension: App Group container URL is nil")
            print("❌ Extension: App Group ID used: \(appGroupID)")
            return
        }

        print("✅ Extension: App Group URL found: \(containerURL)")

        let storeURL = containerURL.appendingPathComponent("transactions.store")
        print("💾 Extension: store URL: \(storeURL)")

        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: Transaction.self, configurations: config)
            let context = ModelContext(container)

            let transaction = Transaction(
                amount: parsed.amount,
                currency: parsed.currency,
                merchant: parsed.merchant,
                category: parsed.category,
                date: parsed.date,
                rawNotificationText: rawText,
                source: .bankPush
            )

            context.insert(transaction)
            try context.save()
            print("✅ Extension: Transaction saved successfully")

        } catch {
            print("❌ Extension: SwiftData error: \(error)")
        }
    }
}
