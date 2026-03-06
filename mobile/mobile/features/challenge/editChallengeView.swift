import SwiftUI

struct EditChallengeView: View {
    @StateObject private var viewModel: EditChallengeViewModel
    @Environment(\.dismiss) private var dismiss

    // UI-only state — sheet visibility and calendar cursor stay in the view, not the VM.
    @State private var showFromDateSheet: Bool = false
    @State private var showToDateSheet: Bool = false
    @State private var monthCursor: Date = Date()           // Tracks which month is visible in the monthly day picker.
    @State private var showDeleteConfirmation: Bool = false // Guards the destructive delete action.

    // Custom init required to forward challengeId into the @StateObject at creation time.
    init(challengeId: UUID) {
        self._viewModel = StateObject(wrappedValue: EditChallengeViewModel(challengeId: challengeId))
    }

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            headerPreview
                            titleSection
                            descriptionSection
                            dailyTasksSection
                            durationSection
                            repeatSection
                            proofSection
                            invitedSection
                            inviteActions
                            saveChangesButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navBarHidden(true)
        .onChange(of: viewModel.didSaveSuccessfully) { saved in
            if saved { dismiss() }
        }
        .onChange(of: viewModel.didDeleteSuccessfully) { deleted in
            if deleted { dismiss() }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("Delete Challenge", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteChallenge() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the challenge and all its tasks.")
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
    }

    // MARK: - Header bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image("back_button")
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color("Neutral-900")))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Edit Challenge")
                .appFont(AppFont.title2)
                .foregroundColor(.white)

            Spacer()

            Button(action: { showDeleteConfirmation = true }) {
                Image("trashcan")
                    .renderingMode(.template)
                    .foregroundColor(Color("Red-500"))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color("Neutral-900")))
            }
            .buttonStyle(.plain)
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
                .foregroundColor(Color("White"))
                .padding(.horizontal, 16)
                .frame(height: 48)
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

            // Use .font() directly — appFont's .fixedSize(vertical:true) collapses the tappable area.
            TextEditor(text: $viewModel.descriptionText)
                .font(AppFont.body2.font)
                .foregroundColor(Color("White"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if viewModel.descriptionText.isEmpty {
                        Text("Add a short description...")
                            .font(AppFont.body2.font)
                            .foregroundColor(Color("Neutral-500"))
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

    // MARK: - Daily tasks
    private var dailyTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Daily Tasks")

            VStack(spacing: 8) {
                ForEach(viewModel.dailyTasks.indices, id: \.self) { index in
                    HStack(spacing: 10) {
                        TextField("Task", text: $viewModel.dailyTasks[index])
                            .appFont(AppFont.body1)
                            .foregroundColor(Color("White"))

                        Button {
                            viewModel.dailyTasks.remove(at: index)
                        } label: {
                            Image("trashcan")
                                .renderingMode(.template)
                                .foregroundColor(Color("Red-500"))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color("Neutral-600"), lineWidth: 0.7)
                    )
                }

                if viewModel.dailyTasks.count < 5 {
                    outlineButton(title: "Add Task", iconName: "plus", isSystem: true, isDashed: false) {
                        viewModel.dailyTasks.append("")
                    }
                }
            }
        }
    }

    // MARK: - Duration
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Duration")

            VStack(spacing: 0) {
                Button { showFromDateSheet = true } label: {
                    selectionRow(
                        iconName: "calendar",
                        title: "From",
                        value: viewModel.fromDateSelected ? dateFormatter.string(from: viewModel.fromDate) : "None",
                        trailingIconName: "chevronRight"
                    )
                }
                .buttonStyle(.plain)

                divider

                Button { showToDateSheet = true } label: {
                    selectionRow(
                        iconName: "calendar",
                        title: "To",
                        value: viewModel.toDateSelected ? dateFormatter.string(from: viewModel.toDate) : "None",
                        trailingIconName: "chevronRight"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
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
                        Text("Repeat")
                            .appFont(AppFont.labelM)
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
                RoundedRectangle(cornerRadius: 12)
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
                    .onTapGesture { viewModel.toggleWeeklyDay(i) }
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

    // MARK: - Proof type
    private var proofSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Proof Type")

            VStack(spacing: 10) {
                VStack(spacing: 0) {
                    Button { viewModel.selectedProof = .photo } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "photo")
                            Text("Photo Upload").appFont(AppFont.labelM)
                        }
                        .foregroundColor(viewModel.selectedProof == .photo ? Color("White") : Color("Neutral-400"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, viewModel.selectedProof == .photo ? 10 : 14)
                    }
                    .buttonStyle(.plain)

                    if viewModel.selectedProof == .photo {
                        HStack(spacing: 0) {
                            Button { viewModel.isProofRequired = true } label: {
                                HStack(spacing: 6) {
                                    if viewModel.isProofRequired {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color("Green-300"))
                                    }
                                    Text("Required").appFont(AppFont.labelM)
                                }
                                .foregroundColor(viewModel.isProofRequired ? Color("White") : Color("Neutral-400"))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(viewModel.isProofRequired ? Color("Neutral-800") : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)

                            Button { viewModel.isProofRequired = false } label: {
                                Text("Optional").appFont(AppFont.labelM)
                                    .foregroundColor(viewModel.isProofRequired ? Color("Neutral-400") : Color("White"))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(viewModel.isProofRequired ? Color.clear : Color("Neutral-800"))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color("Neutral-900"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 10)

                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color("Neutral-500"))
                            Text("Each check-in MUST have a photo to count towards progress.")
                                .appFont(AppFont.captionS)
                                .foregroundColor(Color("Neutral-500"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    }
                }
                .background(Color("Neutral-900"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(viewModel.selectedProof == .photo ? Color("White") : Color("Neutral-700"), lineWidth: 1)
                )

                Button { viewModel.selectedProof = .checklist } label: {
                    HStack(spacing: 8) {
                        Image("checkboxEmpty")
                        Text("Checklist").appFont(AppFont.labelM)
                    }
                    .foregroundColor(viewModel.selectedProof == .checklist ? Color("White") : Color("Neutral-400"))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
                .background(Color("Neutral-900"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(viewModel.selectedProof == .checklist ? Color("White") : Color("Neutral-700"), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Members + pending invites
    @ViewBuilder
    private var invitedSection: some View {
        if !viewModel.members.isEmpty || !viewModel.pendingInvites.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Members")

                VStack(spacing: 10) {
                    ForEach(viewModel.members, id: \.userId) { member in
                        HStack(spacing: 10) {
                            AvatarView(imageURLOrName: member.avatarUrl, size: 36)
                            Text(member.name ?? "Unknown")
                                .appFont(AppFont.labelM)
                                .foregroundColor(.white)
                            Spacer()
                            Text(member.role == "owner" ? "Owner" : "Joined")
                                .appFont(AppFont.captionS)
                                .foregroundColor(member.role == "owner" ? Color("Neutral-200") : Color("Neutral-500"))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(Color("Neutral-900"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    ForEach(viewModel.pendingInvites) { invite in
                        HStack(spacing: 10) {
                            AvatarView(imageURLOrName: invite.avatarUrl, size: 36)
                            Text(invite.name ?? "Unknown")
                                .appFont(AppFont.labelM)
                                .foregroundColor(.white)
                            Spacer()
                            Text(invite.status.capitalized)
                                .appFont(AppFont.captionS)
                                .foregroundColor(Color("Neutral-500"))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(Color("Neutral-900"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Invite action buttons
    private var inviteActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            outlineButton(title: "Add Friends",    iconName: "friends",        isSystem: false, isDashed: true)  {}
            outlineButton(title: "Invite via Link", iconName: "arrowsCircular", isSystem: false, isDashed: false) {}
        }
    }

    // MARK: - Save button
    private var saveChangesButton: some View {
        Button {
            Task { await viewModel.updateChallenge() }
        } label: {
            if viewModel.isSaving {
                ProgressView()
                    .tint(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color("Green-300").opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Save Changes")
                    .appFont(AppFont.title3)
                    .foregroundColor(viewModel.isSaveEnabled ? .black : Color("Neutral-500"))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(viewModel.isSaveEnabled ? Color("Green-300") : Color("Neutral-800"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isSaveEnabled || viewModel.isSaving)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .appFont(AppFont.labelS)
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
        HStack(spacing: 12) {
            Image(iconName)
            Text(title)
                .appFont(AppFont.labelM)
                .foregroundColor(Color("Neutral-300"))
            Spacer()
            Text(value)
                .appFont(AppFont.body2)
                .foregroundColor(Color("White"))
            Image(trailingIconName)
                .foregroundColor(Color("Neutral-400"))
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }

    private func outlineButton(title: String, iconName: String, isSystem: Bool, isDashed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isSystem { Image(systemName: iconName) } else { Image(iconName) }
                Text(title).appFont(AppFont.labelM)
            }
            .foregroundColor(Color("White"))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color("Neutral-900"))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("Neutral-700"), style: StrokeStyle(lineWidth: 1, dash: isDashed ? [6, 6] : []))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EditChallengeView(challengeId: UUID())
}
