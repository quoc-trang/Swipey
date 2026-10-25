import SwiftUI
import Photos

private enum SwipeyMode: String, CaseIterable {
    case photos = "Photos"
    case gmail = "Gmail"
}

public struct ContentView: View {
    @State private var photoService = PhotoLibraryService.shared
    @State private var swipeViewModel = SwipeViewModel()
    @State private var gmailViewModel = GmailViewModel()
    @State private var selectedMode: SwipeyMode = .photos

    @State private var showOnboarding: Bool = false
    @State private var showFilterSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showReviewSheet: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(SwipeyMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .zIndex(1)

                ZStack {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    if selectedMode == .gmail {
                        GmailModeView(viewModel: gmailViewModel)
                    } else if photoService.isAuthorized {
                        mainSwipeInterface
                    } else {
                        PermissionView(photoService: photoService) {
                            swipeViewModel.reload()
                        }
                    }
                }
            }
            .navigationTitle("Swipey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedMode == .photos && photoService.isAuthorized {
                    // Leading: Filter selector
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showFilterSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                Text(filterButtonTitle)
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }

                    // Trailing: Settings & Review Button
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // Review & Delete Button with badge
                        Button {
                            showReviewSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trash")
                                if !swipeViewModel.toDelete.isEmpty {
                                    Text("\(swipeViewModel.toDelete.count)")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .tint(swipeViewModel.toDelete.isEmpty ? .secondary : .red)

                        Button {
                            showSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(viewModel: swipeViewModel)
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(viewModel: swipeViewModel)
            }
            .sheet(isPresented: $showReviewSheet) {
                ReviewGridView(
                    viewModel: ReviewViewModel(
                        markedItems: swipeViewModel.toDelete,
                        photoService: photoService
                    )
                ) { remainingMarked in
                    swipeViewModel.toDelete = remainingMarked
                }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .onAppear {
                let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .task(id: selectedMode) {
                guard selectedMode == .photos, photoService.isAuthorized else { return }
                swipeViewModel.reload()
            }
        }
    }

    private var filterButtonTitle: String {
        if let monthYear = swipeViewModel.selectedMonthYear {
            return monthYear.displayName
        }
        return swipeViewModel.selectedCategory.rawValue
    }

    private var mainSwipeInterface: some View {
        VStack(spacing: 0) {
            // Category / Progress Subheader
            HStack {
                Text("\(swipeViewModel.remainingCount) photos remaining")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if swipeViewModel.estimatedFreedBytes > 0 {
                    let sizeStr = ByteCountFormatter.string(fromByteCount: swipeViewModel.estimatedFreedBytes, countStyle: .file)
                    Text("Pending: \(sizeStr)")
                        .font(.footnote.bold())
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Swipe Card Stack
            SwipeStackView(viewModel: swipeViewModel) {
                showReviewSheet = true
            }
        }
    }
}

#Preview {
    let vm = SwipeViewModel(isMockMode: true)
    vm.loadMockData()
    var view = ContentView()
    return view
}
