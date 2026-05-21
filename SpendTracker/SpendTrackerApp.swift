import SwiftUI
import SwiftData
import UserNotifications

@main
struct SpendTrackerApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Transaction.self])

        if let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.harshal.spendtracker") {
            let storeURL = containerURL.appendingPathComponent("transactions.store")
            let config = ModelConfiguration(url: storeURL)
            if let container = try? ModelContainer(for: Transaction.self, configurations: config) {
                print("✅ Using App Group container")
                return container
            }
        }

        print("⚠️ Using local storage")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: Transaction.self, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    print("🔗 onOpenURL fired: \(url.absoluteString)")
                    // Tell clipboard monitor this was a URL open, not a manual open
                    UserDefaults.standard.set(true, forKey: "openedViaURL")
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - URL Handler
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "spendtracker", url.host == "parse" else {
            print("❌ Wrong scheme or host")
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let textItem = components.queryItems?.first(where: { $0.name == "text" }),
              let smsText = textItem.value,
              !smsText.isEmpty else {
            print("❌ Could not extract text from URL")
            return
        }

        print("📱 SMS text from URL: \(smsText)")
        appDelegate.handleIncomingSMS(smsText)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var modelContainer: ModelContainer?

    // MARK: - App Launch
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        setupModelContainer()

        // Handle URL if app was launched from killed state via URL scheme
        if let url = launchOptions?[.url] as? URL {
            print("🚀 App launched via URL: \(url.absoluteString)")
            _ = self.application(application, open: url, options: [:])
        }

        return true
    }

    // MARK: - URL Scheme (fallback for older iOS behaviour)
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard url.scheme == "spendtracker", url.host == "parse" else { return false }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let textItem = components.queryItems?.first(where: { $0.name == "text" }),
              let smsText = textItem.value,
              !smsText.isEmpty else {
            print("❌ No text parameter in URL")
            return false
        }

        print("📱 SMS received via URL scheme: \(smsText)")
        handleIncomingSMS(smsText)
        return true
    }

    // MARK: - Core SMS Handler
    func handleIncomingSMS(_ text: String) {
        guard looksLikeTransaction(text) else {
            print("⏭ Skipped — doesn't look like a transaction")
            return
        }

        guard let parsed = NotificationParser.parse(notificationBody: text) else {
            print("❌ Parser returned nil — saving as uncategorized")
            saveRawTransaction(text)
            return
        }

        print("✅ Parsed from SMS: \(parsed.merchant) - \(parsed.amount)")
        saveTransaction(parsed, rawText: text)
        NotificationCenter.default.post(name: .newTransactionAdded, object: nil)
    }

    // MARK: - Notification Handling
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleIncomingSMS("\(notification.request.content.title) \(notification.request.content.body)")
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleIncomingSMS("\(response.notification.request.content.title) \(response.notification.request.content.body)")
        completionHandler()
    }

    // MARK: - Transaction Filter
    private func looksLikeTransaction(_ text: String) -> Bool {
        let keywords = [
            "debited", "credited", "purchase", "payment",
            "SAR", "SR", "AED", "USD", "EUR", "GBP",
            "spent", "charged", "was used for", "used for",
            "تم الخصم", "تم الإيداع", "مدين", "دائن"
        ]
        return keywords.contains { text.lowercased().contains($0) }
    }

    // MARK: - Save Helpers
    private func saveTransaction(_ parsed: ParsedTransaction, rawText: String) {
        let transaction = Transaction(
            amount: parsed.amount,
            currency: parsed.currency,    // ← add this
            merchant: parsed.merchant,
            category: parsed.category,
            date: parsed.date,
            rawNotificationText: rawText,
            source: .sms
        )
        saveTransactionObject(transaction)
    }

    private func saveRawTransaction(_ rawText: String) {
        let transaction = Transaction(
            amount: 0.0,
            currency: "XXX",
            merchant: "Review Required",
            category: .uncategorized,
            date: .now,
            rawNotificationText: rawText,
            source: .sms
        )
        saveTransactionObject(transaction)
    }

    private func saveTransactionObject(_ transaction: Transaction) {
        guard let container = modelContainer else {
            print("❌ No model container")
            return
        }
        let context = ModelContext(container)
        context.insert(transaction)
        do {
            try context.save()
            print("✅ Saved: \(transaction.merchant)")
        } catch {
            print("❌ Save error: \(error)")
        }
    }

    // MARK: - Setup
    private func setupModelContainer() {
        if let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.harshal.spendtracker") {
            let storeURL = containerURL.appendingPathComponent("transactions.store")
            let config = ModelConfiguration(url: storeURL)
            modelContainer = try? ModelContainer(for: Transaction.self, configurations: config)
        }

        if modelContainer == nil {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try? ModelContainer(for: Transaction.self, configurations: config)
            print("⚠️ Using local storage")
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            print(granted ? "✅ Notifications allowed" : "❌ Notifications denied")
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let newTransactionAdded = Notification.Name("newTransactionAdded")
}
