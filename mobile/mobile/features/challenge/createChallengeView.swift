import SwiftUI

struct CreateChallengeView: View {
    @StateObject private var viewModel = CreateChallengeViewModel()
    @Environment(\.dismiss) private var dismiss

    // UI-only state — sheet visibility and calendar cursor stay in the view, not the VM.
    @State private var showFromDateSheet: Bool = false
    @State private var showToDateSheet: Bool = false
    @State private var showInviteFriends: Bool = false
    @State private var showEmojiSetup: Bool = false
    @State private var monthCursor: Date = Date()  // Tracks which month is visible in the monthly day picker.

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerPreview
                        titleSection
                        descriptionSection
                        dailyTasksSection
                        durationSection
                        repeatSection
                        proofSection
                        inviteSection
                        createButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .navBarHidden(true)
        .dismissKeyboardOnTap()
        .onChange(of: viewModel.didCreateSuccessfully) { didCreate in
            if didCreate { dismiss() }
        }
        // MARK: - Emoji Setup screen
        .fullScreenCover(isPresented: $showEmojiSetup) {
            EmojiSetupView(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // MARK: - "From" date calendar overlay
        .overlay {
            if showFromDateSheet {
                ChangeDateSheet(
                    initialDate: viewModel.fromDate,
                    onConfirm: { picked in
                        viewModel.fromDate = picked
                        viewModel.fromDateSelected = true
                        if viewModel.toDateSelected && viewModel.toDate < picked {
                            viewModel.toDate = picked
                        }
                        showFromDateSheet = false
                    },
                    onCancel: { showFromDateSheet = false }
                )
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showFromDateSheet)
        // MARK: - "To" date calendar overlay
        .overlay {
            if showToDateSheet {
                ChangeDateSheet(
                    initialDate: viewModel.toDateSelected ? viewModel.toDate : viewModel.fromDate,
                    onConfirm: { picked in
                        viewModel.toDate = picked
                        viewModel.toDateSelected = true
                        showToDateSheet = false
                    },
                    onCancel: { showToDateSheet = false }
                )
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showToDateSheet)
        // MARK: - Invite friends sheet
        .fullScreenCover(isPresented: $showInviteFriends) {
            InviteFriendsView(invitedFriends: $viewModel.invitedFriends)
        }
    }

    // MARK: - Header bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image("back_button")
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color("Neutral-900"))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Create Challenge")
                .appFont(AppFont.title2)
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.top, 8)
    }

    private var headerPreview: some View {
        Image("jar")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 140)
            .opacity(0.9)
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(.top, 8)
    }

    // MARK: - Challenge title
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Challenge Title")

            TextField("Challenge Title", text: $viewModel.challengeTitle)
                .appFont(AppFont.body1)
                .foregroundColor(Color("Neutral-300"))
                .padding(.horizontal, 18)
                .frame(height: 49)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                )
        }
    }

    // MARK: - Description
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Description")

            // Use .font() directly instead of .appFont() — appFont applies .fixedSize(vertical:true)
            // which collapses the TextEditor's interactive area to ~one line, making it untappable.
            TextEditor(text: $viewModel.descriptionText)
                .font(AppFont.body1.font)
                .foregroundColor(Color("White"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 84)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if viewModel.descriptionText.isEmpty {
                        Text("Add a short description...")
                            .font(AppFont.body1.font)
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                )
        }
    }

    // MARK: - Daily tasks list with swipe-to-delete
    private var dailyTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Daily Tasks")

            List {
                ForEach(viewModel.dailyTasks.indices, id: \.self) { index in
                    TextField("Task", text: $viewModel.dailyTasks[index])
                        .appFont(AppFont.body1)
                        .foregroundColor(Color("White"))
                        .padding(.horizontal, 14)
                        .frame(height: 49)
                        .background(AppColors.neutral1000)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    viewModel.dailyTasks.remove(atOffsets: indexSet)
                }
            }
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .frame(height: CGFloat(viewModel.dailyTasks.count) * 57)

            if viewModel.dailyTasks.count < 5 {
                outlineButton(title: "Add Task", iconName: "addTask", isSystem: false, isDashed: true, iconSize: CGSize(width: 14, height: 14)) {
                    viewModel.dailyTasks.append("")
                }
            }
        }
    }

    // MARK: - Duration (From / To with calendar popup)
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Duration")

            VStack(spacing: 0) {
                Button { hideKeyboard(); showFromDateSheet = true } label: {
                    selectionRow(
                        iconName: "duration",
                        title: "From",
                        value: viewModel.fromDateSelected ? dateFormatter.string(from: viewModel.fromDate) : "None",
                        trailingIconName: "chevronRight"
                    )
                }
                .buttonStyle(.plain)

                divider

                Button { hideKeyboard(); showToDateSheet = true } label: {
                    selectionRow(
                        iconName: "duration",
                        title: "To",
                        value: viewModel.toDateSelected ? dateFormatter.string(from: viewModel.toDate) : "None",
                        trailingIconName: "chevronRight"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
            )
        }
    }

    // MARK: - Repeat
    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Repeat")

            VStack(spacing: 0) {
                HStack {
                    HStack {
                        Image("repeat")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Repeat")
                            .appFont(AppFont.labelL)
                            .foregroundColor(Color("Neutral-300"))
                    }
                    Spacer()
                    Menu {
                        ForEach(RepeatType.allCases, id: \.self) { t in
                            Button(t.displayName) { viewModel.repeatType = t }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.repeatType.displayName)
                                .appFont(AppFont.body1)
                                .foregroundColor(.white)
                            Image("chevronUpdown")
                        }
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 11)

                if viewModel.repeatType == .weekly {
                    divider
                    weeklyChips
                }

                if viewModel.repeatType == .monthly {
                    divider
                    monthlyPickerInsideBox
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
            )
        }
    }

    // Capsule day-of-week toggles, shown inline when repeat type is Weekly.
    private var weeklyChips: some View {
        let labels = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return HStack(spacing: 7) {
            ForEach(0..<7, id: \.self) { i in
                let selected = viewModel.selectedWeeklyDays.contains(i)
                Text(labels[i])
                    .appFont(AppFont.captionXS)
                    .foregroundStyle(selected ? Color.black : Color("Neutral-50"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(selected ? Color("Green-300") : Color("Neutral-900")))
                    .onTapGesture {
                        viewModel.toggleWeeklyDay(i)
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 20)
        .padding(.bottom, 21)
    }

    // Full calendar month picker for day-of-month selection, shown inline when repeat type is Monthly.
    @ViewBuilder
    private var monthlyPickerInsideBox: some View {
        VStack(spacing: 0) {
            CustomCalendarMulti(
                monthAnchor: $monthCursor,
                selectedDays: $viewModel.selectedMonthlyDays
            )
        }
        .padding(.bottom, 16)
    }

    // MARK: - Proof type with Required/Optional toggle
    private var proofSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Proof Type")

            VStack(spacing: 10) {
                // Photo Upload card — expands to show toggle+helper when selected
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image("camera")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Photo Upload")
                            .appFont(AppFont.labelL)
                    }
                    .foregroundColor(viewModel.selectedProof.isPhoto ? Color("White") : Color("Neutral-300"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11)
                    .padding(.top, 11)
                    .padding(.bottom, 10)

                    // Toggle + helper text — only shown when Photo Upload is active
                    if viewModel.selectedProof.isPhoto {
                        VStack(alignment: .leading, spacing: 8) {
                            // Required / Optional toggle
                            HStack(spacing: 0) {
                                Button {
                                    updateProofSelection(.photoRequired)
                                } label: {
                                    HStack(spacing: 8) {
                                        if viewModel.selectedProof == .photoRequired {
                                            Image("proofTypeSelected")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                        }
                                        Text("Required")
                                            .appFont(AppFont.labelM)
                                    }
                                    .foregroundColor(viewModel.selectedProof == .photoRequired ? Color("White") : Color("Neutral-400"))
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(viewModel.selectedProof == .photoRequired ? Color("Neutral-300") : Color.clear, lineWidth: 0.7)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    updateProofSelection(.photoOptional)
                                } label: {
                                    HStack(spacing: 8) {
                                        if viewModel.selectedProof == .photoOptional {
                                            Image("proofTypeSelected")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                        }
                                        Text("Optional")
                                            .appFont(AppFont.labelM)
                                    }
                                    .foregroundColor(viewModel.selectedProof == .photoOptional ? Color("White") : Color("Neutral-400"))
                                    .frame(maxWidth: .infinity, minHeight: 42)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(viewModel.selectedProof == .photoOptional ? Color("Neutral-300") : Color.clear, lineWidth: 0.7)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .background(Color("Neutral-800"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            HStack(spacing: 9) {
                                Image("photo_upload_info")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                Text(viewModel.selectedProof == .photoRequired
                                     ? "Each check-in MUST have a photo to count towards progress."
                                     : "Users can upload a photo or skip it.")
                                    .appFont(AppFont.captionXS)
                                    .foregroundColor(Color("Neutral-300"))
                            }
                        }
                        .padding(.leading, 39)
                        .padding(.trailing, 12)
                        .padding(.bottom, 14)
                        .padding(.top, 2)
                    }
                }
                .background(Color("Neutral-900"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(viewModel.selectedProof.isPhoto ? Color("White") : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if !viewModel.selectedProof.isPhoto {
                        updateProofSelection(.photoRequired)
                    }
                }

                // Checklist card
                Button {
                    updateProofSelection(.checklist)
                } label: {
                    HStack(spacing: 6) {
                        Image("checklist")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Checklist")
                            .appFont(AppFont.labelL)
                    }
                    .foregroundColor(viewModel.selectedProof == .checklist ? Color("White") : Color("Neutral-300"))
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .padding(.horizontal, 11)
                    .background(Color("Neutral-900"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(viewModel.selectedProof == .checklist ? Color("White") : Color.clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .animation(.none, value: viewModel.selectedProof)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    // MARK: - Invite participants
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Invite Friends")

            VStack(spacing: 10) {
                // Show invited count badge when friends are selected
                if !viewModel.invitedFriends.isEmpty {
                    HStack {
                        Image("friends")
                        Text("\(viewModel.invitedFriends.count) friend\(viewModel.invitedFriends.count == 1 ? "" : "s") invited")
                            .appFont(AppFont.labelM)
                            .foregroundColor(Color("White"))
                        Spacer()
                        Button {
                            showInviteFriends = true
                        } label: {
                            Text("Edit")
                                .appFont(AppFont.captionS)
                                .foregroundColor(Color("Neutral-400"))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color("Neutral-900"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color("Neutral-700"), lineWidth: 1)
                    )
                }

                outlineButton(title: "Add Friends", iconName: "addFriends", isSystem: false, isDashed: true, iconSize: CGSize(width: 14, height: 14)) {
                    showInviteFriends = true
                }
            }
        }
    }

    // MARK: - Continue button (navigates to Emoji Setup)
    private var createButton: some View {
        Button {
            showEmojiSetup = true
        } label: {
            Text("Continue")
                .appFont(AppFont.buttonL)
                .foregroundColor(viewModel.isCreateEnabled ? Color("Neutral-1000") : Color("Neutral-500"))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(viewModel.isCreateEnabled ? Color("Green-300") : Color("Neutral-800"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!viewModel.isCreateEnabled)
        .padding(.top, 20)
    }

    // MARK: - Date display formatter (e.g. "Feb 11, 2026")
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .appFont(AppFont.labelM)
            .foregroundColor(Color("Neutral-300"))
            .padding(.leading, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color("Neutral-800"))
            .frame(height: 0.7)
            .padding(.horizontal, 12)
    }

    private func selectionRow(iconName: String, title: String, value: String, trailingIconName: String) -> some View {
        HStack(spacing: 6) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            Text(title)
                .appFont(AppFont.labelL)
                .foregroundColor(Color("Neutral-300"))

            Spacer()

            Text(value)
                .appFont(AppFont.body1)
                .foregroundColor(Color("White"))

            Image(trailingIconName)
                .foregroundColor(Color("Neutral-400"))
        }
        .padding(.horizontal, 11)
        .frame(height: 52)
    }

    private func outlineButton(title: String, iconName: String, isSystem: Bool, isDashed: Bool, showBorder: Bool = true, iconSize: CGSize? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isSystem {
                    Image(systemName: iconName)
                } else if let size = iconSize {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                } else {
                    Image(iconName)
                }
                Text(title)
                    .appFont(AppFont.labelM)
            }
            .foregroundColor(Color("Neutral-300"))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color("Neutral-900"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        showBorder ? Color("Neutral-600") : Color.clear,
                        style: StrokeStyle(lineWidth: 0.7, dash: isDashed ? [6, 6] : [])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func updateProofSelection(_ proof: ProofType) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            viewModel.selectedProof = proof
        }
    }
}


private struct SelectableChip: View {
    let title: String
    let imageName: String
    let isSystemImage: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSystemImage {
                    Image(systemName: imageName)
                } else {
                    Image(imageName)
                }
                Text(title)
                    .appFont(AppFont.labelM)
            }
            .foregroundColor(isSelected ? Color("White") : Color("Neutral-400"))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color("Neutral-900"))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color("White") : Color("Neutral-700"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateChallengeView()
}
