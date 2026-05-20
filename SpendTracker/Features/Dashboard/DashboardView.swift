import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedPeriod: Period = .thisMonth

    enum Period: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case threeMonths = "3 Months"
    }

    var filtered: [Transaction] {
        let now = Date()
        let calendar = Calendar.current

        let startDate: Date = {
            switch selectedPeriod {
            case .thisWeek:
                return calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .thisMonth:
                return calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .threeMonths:
                return calendar.date(byAdding: .month, value: -3, to: now) ?? now
            }
        }()

        return transactions.filter { $0.date >= startDate }
    }

    var totalSpend: Double {
        filtered.reduce(0) { $0 + $1.amount }
    }

    var spendByCategory: [(category: Category, total: Double)] {
        let grouped = Dictionary(grouping: filtered, by: \.category)
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Period Picker
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(Period.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // MARK: - Total Spend Card
                    TotalSpendCard(total: totalSpend, period: selectedPeriod.rawValue, count: filtered.count)

                    // MARK: - Category Chart
                    if !spendByCategory.isEmpty {
                        CategoryChartCard(data: spendByCategory)
                    }

                    // MARK: - Category Breakdown
                    if !spendByCategory.isEmpty {
                        CategoryBreakdownCard(data: spendByCategory, total: totalSpend)
                    }

                    // MARK: - Empty State
                    if filtered.isEmpty {
                        EmptyStateView()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Total Spend Card
struct TotalSpendCard: View {
    let total: Double
    let period: String
    let count: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Total Spent")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("SAR \(total, specifier: "%.2f")")
                .font(.system(size: 42, weight: .bold, design: .rounded))
            Text("\(count) transactions · \(period)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Category Chart Card
struct CategoryChartCard: View {
    let data: [(category: Category, total: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spend by Category")
                .font(.headline)
                .padding(.horizontal)

            Chart(data, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(categoryColor(item.category))
                .cornerRadius(4)
            }
            .frame(height: 220)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func categoryColor(_ category: Category) -> Color {
        switch category {
        case .food: return .orange
        case .transport: return .blue
        case .shopping: return .purple
        case .utilities: return .yellow
        case .entertainment: return .pink
        case .health: return .red
        case .travel: return .teal
        case .uncategorized: return .gray
        }
    }
}

// MARK: - Category Breakdown Card
struct CategoryBreakdownCard: View {
    let data: [(category: Category, total: Double)]
    let total: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Breakdown")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(data, id: \.category) { item in
                CategoryBreakdownRow(item: item, total: total)
                if item.category != data.last?.category {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Category Breakdown Row
struct CategoryBreakdownRow: View {
    let item: (category: Category, total: Double)
    let total: Double

    var percentage: Double {
        total > 0 ? (item.total / total) * 100 : 0
    }

    var color: Color {
        switch item.category {
        case .food: return .orange
        case .transport: return .blue
        case .shopping: return .purple
        case .utilities: return .yellow
        case .entertainment: return .pink
        case .health: return .red
        case .travel: return .teal
        case .uncategorized: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(item.category.rawValue)
                .font(.subheadline)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SAR \(item.total, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(percentage, specifier: "%.0f")%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
