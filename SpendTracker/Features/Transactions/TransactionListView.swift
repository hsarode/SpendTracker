import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCategory: Category? = nil
    @State private var searchText: String = ""

    var filtered: [Transaction] {
        transactions.filter { transaction in
            let matchesCategory = selectedCategory == nil || transaction.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                transaction.merchant.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // MARK: - Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            icon: "square.grid.2x2",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }

                        ForEach(Category.allCases, id: \.self) { category in
                            FilterChip(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category == selectedCategory ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemBackground))

                Divider()

                // MARK: - Transaction List
                if filtered.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(groupedByDate.keys.sorted(by: >), id: \.self) { date in
                            Section(header: Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ) {
                                ForEach(groupedByDate[date] ?? []) { transaction in
                                    TransactionRow(transaction: transaction)
                                }
                                .onDelete { indexSet in
                                    deleteTransactions(from: groupedByDate[date] ?? [], at: indexSet)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search merchant")
        }
    }

    // MARK: - Grouping
    private var groupedByDate: [Date: [Transaction]] {
        Dictionary(grouping: filtered) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }

    // MARK: - Delete
    private func deleteTransactions(from group: [Transaction], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(group[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.category.icon)
                    .foregroundColor(categoryColor)
                    .font(.system(size: 18))
            }

            // Merchant + Category
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(transaction.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount + Source
            VStack(alignment: .trailing, spacing: 3) {
                // Replace the amount Text in TransactionRow
                Text("\(transaction.currency) \(transaction.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(transaction.source.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch transaction.category {
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

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Transactions")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Parse notifications from the Debug tab\nor wait for bank notifications to appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}
