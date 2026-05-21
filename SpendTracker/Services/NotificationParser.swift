import Foundation

struct ParsedTransaction {
    let amount: Double
    let currency: String
    let merchant: String
    let date: Date
    let category: Category
}

struct NotificationParser {

    // MARK: - Main Entry Point
    static func parse(notificationBody: String) -> ParsedTransaction? {
        guard let amount = extractAmount(from: notificationBody) else { return nil }
        let currency = extractCurrency(from: notificationBody)
        let merchant = extractMerchant(from: notificationBody)
        let date = extractDate(from: notificationBody) ?? .now
        let category = categorize(merchant: merchant, body: notificationBody)

        return ParsedTransaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            date: date,
            category: category
        )
    }
    // MARK: - Currency Extraction
    static func extractCurrency(from text: String) -> String {
        // Order matters — check specific ones first
        let currencies = ["AED", "SAR", "USD", "EUR", "GBP"]
        for currency in currencies {
            if text.contains(currency) { return currency }
        }
        return "XXX"
    }

    // MARK: - Amount Extraction
    static func extractAmount(from text: String) -> Double? {
        let patterns = [
            #"(?:SAR|SR|ريال)\s*([\d,]+\.?\d*)"#,
            #"(?:AED|ريال)\s*([\d,]+\.?\d*)"#,
            #"(?:INR|ريال)\s*([\d,]+\.?\d*)"#,
            #"([\d,]+\.?\d*)\s*(?:SAR|SR|ريال)"#,
            #"(?:Amount|amount|AMOUNT)[:\s]+([\d,]+\.?\d*)"#,
            #"(?:debited|charged|spent)[^\d]*([\d,]+\.?\d*)"#
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedString = String(text[match])
                let numberPattern = #"[\d,]+\.?\d*"#
                if let numberMatch = matchedString.range(of: numberPattern, options: .regularExpression) {
                    let numberString = String(matchedString[numberMatch])
                        .replacingOccurrences(of: ",", with: "")
                    return Double(numberString)
                }
            }
        }
        return nil
    }

    // MARK: - Merchant Extraction
    static func extractMerchant(from text: String) -> String {
        let patterns = [
            #"(?:at|AT|@)\s+([A-Z][A-Z0-9\s]{2,25}?)\s+(?:on|for|ON|FOR)\b"#,
            #"(?:at|AT|@)\s+([A-Z][A-Za-z0-9\s\*]{2,30}?)(?:\s+on|\s+for|\.|,|$)"#,
            #"(?:to|TO)\s+([A-Z][A-Za-z0-9\s]{2,30}?)(?:\s+on|\s+for|\.|,|$)"#,
            #"(?:merchant|Merchant)[:\s]+([A-Za-z0-9\s]{2,30}?)(?:\.|,|$)"#
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                var merchant = String(text[match])
                ["at ", "AT ", "to ", "TO ", "@ ", "merchant:", "Merchant:"].forEach {
                    merchant = merchant.replacingOccurrences(of: $0, with: "")
                }
                return merchant.trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown Merchant"
    }

    // MARK: - Date Extraction
    static func extractDate(from text: String) -> Date? {
        let formatter = DateFormatter()
        let patterns: [(String, String)] = [
            (#"\d{2}/\d{2}/\d{4}"#, "dd/MM/yyyy"),
            (#"\d{4}-\d{2}-\d{2}"#, "yyyy-MM-dd"),
            (#"\d{2}-\d{2}-\d{4}"#, "dd-MM-yyyy")
        ]

        for (pattern, format) in patterns {
            if let matchRange = text.range(of: pattern, options: .regularExpression) {
                formatter.dateFormat = format
                if let date = formatter.date(from: String(text[matchRange])) {
                    return date
                }
            }
        }
        return nil
    }

    // MARK: - Categorization
    static func categorize(merchant: String, body: String) -> Category {
        let combined = (merchant + " " + body).lowercased()

        let categoryKeywords: [(Category, [String])] = [
            (.food, ["starbucks", "mcdonalds", "kfc", "restaurant", "cafe",
                     "coffee", "pizza", "burger", "food", "shawarma", "مطعم", "مقهى"]),
            (.transport, ["uber", "careem", "gas", "fuel", "petrol",
                          "parking", "salik", "aramco"]),
            (.shopping, ["noon", "amazon", "shein", "zara", "h&m", "ikea",
                         "mall", "market", "tamimi", "lulu", "danube"]),
            (.utilities, ["stc", "mobily", "zain", "water", "electricity",
                          "sec", "internet", "netflix"]),
            (.entertainment, ["netflix", "spotify", "steam", "playstation",
                               "cinema", "muvi", "vox"]),
            (.health, ["pharmacy", "hospital", "clinic", "doctor",
                       "medical", "صيدلية", "مستشفى"]),
            (.travel, ["airline", "hotel", "saudia", "flyadeal", "flynas",
                       "booking", "airbnb", "airport"])
        ]

        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { combined.contains($0) }) {
                return category
            }
        }
        return .uncategorized
    }
}
