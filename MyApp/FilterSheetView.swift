import SwiftUI

public struct FilterSheetView: View {
    @Bindable var viewModel: SwipeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSmartSortEnabled: Bool = false

    public init(viewModel: SwipeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Media Category") {
                    ForEach(MediaCategory.allCases) { category in
                        Button {
                            viewModel.selectedCategory = category
                            dismiss()
                        } label: {
                            HStack {
                                Label(category.rawValue, systemImage: category.iconName)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if viewModel.selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                Section("Smart Organization") {
                    Toggle(isOn: $isSmartSortEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Smart Cleaning Order")
                                    .font(.body)
                                Text("Puts screenshots, duplicates, and bursts first")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.purple)
                        }
                    }
                    .onChange(of: isSmartSortEnabled) { _, newValue in
                        if newValue {
                            viewModel.assets = SmartSortService.shared.prioritizeUnwanted(items: viewModel.assets)
                        } else {
                            viewModel.reload()
                        }
                    }
                }

                Section("Filter By Date") {
                    Button {
                        viewModel.selectedMonthYear = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("All Time")
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if viewModel.selectedMonthYear == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    ForEach(recentMonths, id: \.id) { my in
                        Button {
                            viewModel.selectedMonthYear = my
                            dismiss()
                        } label: {
                            HStack {
                                Text(my.displayName)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if viewModel.selectedMonthYear == my {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private var recentMonths: [MonthYearFilter] {
        let calendar = Calendar.current
        var list: [MonthYearFilter] = []
        let today = Date()

        for offset in 0..<18 {
            if let date = calendar.date(byAdding: .month, value: -offset, to: today) {
                let y = calendar.component(.year, from: date)
                let m = calendar.component(.month, from: date)
                list.append(MonthYearFilter(month: m, year: y))
            }
        }
        return list
    }
}

#Preview {
    FilterSheetView(viewModel: SwipeViewModel(isMockMode: true))
}
