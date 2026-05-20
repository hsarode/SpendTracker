import UserNotifications
import SwiftData

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let appGroupID = "group.com.yourname.spendtracker" // ← update this

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let fullText = "\(content.title) \(content.body)"

        if let parsed = NotificationParser.parse(notificationBody: fullText) {
            saveTransaction(parsed, rawText: fullText)
        }

        // Always deliver notification to user unchanged
        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let content = bestAttemptContent {
            contentHandler(content)
        }
    }

    // MARK: - Save to Shared SwiftData Store
    private func saveTransaction(_ parsed: ParsedTransaction, rawText: String) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("❌ Could not find App Group container")
            return
        }

        let storeURL = containerURL.appendingPathComponent("transactions.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            let container = try ModelContainer(for: Transaction.self, configurations: config)
            let transaction = Transaction(
                amount: parsed.amount,
                merchant: parsed.merchant,
                category: parsed.category,
                date: parsed.date,
                rawNotificationText: rawText,
                source: .bankPush
            )
            let context = ModelContext(container)
            context.insert(transaction)
            try context.save()
            print("✅ Transaction saved: \(parsed.merchant) - \(parsed.amount)")
        } catch {
            print("❌ SwiftData error: \(error)")
        }
    }
}
