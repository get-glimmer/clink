import SwiftUI

private struct HiddenEmojiTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool

    private final class EmojiFirstTextField: UITextField {
        override var textInputContextIdentifier: String? { "" }
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
                ?? super.textInputMode
        }
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = EmojiFirstTextField(frame: .zero)
        tf.delegate = context.coordinator
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.tintColor = .clear
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if isFirstResponder && !uiView.isFirstResponder {
            _ = uiView.becomeFirstResponder()
            DispatchQueue.main.async { uiView.reloadInputViews() }
        } else if !isFirstResponder && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HiddenEmojiTextField
        init(_ parent: HiddenEmojiTextField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard !string.isEmpty else { return true }
            parent.text = string
            return false
        }
    }
}

struct EditChallengeView: View {
    @StateObject private var viewModel: EditChallengeViewModel
    @Environment(\.dismiss) private var dismiss

    // UI-only state — sheet visibility and calendar cursor stay in the view, not the VM.
    @State private var showFromDateSheet: Bool = false
    @State private var showToDateSheet: Bool = false
    @State private var monthCursor: Date = Date()           // Tracks which month is visible in the monthly day picker.
    @State private var showDeleteConfirmation: Bool = false // Guards the destructive delete action.
    @State private var showInviteFriends: Bool = false
    @State private var pickerEmoji: String = ""
    @State private var isEmojiKeyboardFocused: Bool = false

    // Custom init required to forward challengeId into the @StateObject at creation time.
    init(challengeId: UUID) {
        self._viewModel = StateObject(wrappedValue: EditChallengeViewModel(challengeId: challengeId))
    }

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            VStack {
                HiddenEmojiTextField(text: $pickerEmoji, isFirstResponder: $isEmojiKeyboardFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.02)
                    .allowsHitTesting(false)
                Spacer()
            }

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
                            if viewModel.emojiRule == .selectedOnly {
                                emojiSetupSection
                            }
                            saveChangesButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .navBarHidden(true)
        .dismissKeyboardOnTap()
        .onChange(of: pickerEmoji) { emoji in
            guard !emoji.isEmpty else { return }
            switch viewModel.emojiRule {
            case .selectedOnly:
                if viewModel.canAddEmoji && !viewModel.presetEmojis.contains(emoji) {
                    viewModel.presetEmojis.append(emoji)
                }
            case .anyEmoji:
                viewModel.presetEmojis = [emoji]
            }
            pickerEmoji = ""
            isEmojiKeyboardFocused = false
        }
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
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsView(invitedFriends: $viewModel.invitedFriends, challengeId: viewModel.challengeId)
        }
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
                    .frame(width: 44, height: 44)
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
                .font(AppFont.body1.font)
                .foregroundColor(Color("White"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if viewModel.descriptionText.isEmpty {
                        Text("Add a short description...")
                            .font(AppFont.body1.font)
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

            List {
                ForEach(viewModel.dailyTasks.indices, id: \.self) { index in
                    TextField("Task", text: $viewModel.dailyTasks[index].title)
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
                    viewModel.dailyTasks.append(TaskEntry(id: nil, title: ""))
                }
            }
        }
    }

    // MARK: - Duration
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

                    if viewModel.selectedProof.isPhoto {
                        VStack(alignment: .leading, spacing: 8) {
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

    // MARK: - Members + pending invites
    @ViewBuilder
    private var invitedSection: some View {
        if !viewModel.members.isEmpty || !viewModel.pendingInvites.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Invite Friends")

                let rowHeight: CGFloat = 58  // 50 item + 4 top + 4 bottom inset
                let totalCount = viewModel.members.count + viewModel.pendingInvites.count

                List {
                    ForEach(viewModel.members, id: \.userId) { member in
                        HStack(spacing: 10) {
                            AvatarView(imageURLOrName: member.avatarUrl, size: 36)
                            Text(member.name ?? "Unknown")
                                .appFont(AppFont.labelM)
                                .foregroundColor(.white)
                            Spacer()
                            Text(member.role == "owner" ? "Owner" : "Joined")
                                .appFont(AppFont.buttonM)
                                .foregroundColor(member.role == "owner" ? Color("Neutral-200") : Color("Neutral-500"))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(Color("Neutral-900").clipShape(RoundedRectangle(cornerRadius: 10)))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if member.role != "owner" {
                                Button(role: .destructive) {
                                    Task { await viewModel.removeMember(userId: member.userId) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                    ForEach(viewModel.pendingInvites) { invite in
                        HStack(spacing: 10) {
                            AvatarView(imageURLOrName: invite.avatarUrl, size: 36)
                            Text(invite.name ?? "Unknown")
                                .appFont(AppFont.labelM)
                                .foregroundColor(.white)
                            Spacer()
                            Text(invite.status.capitalized)
                                .appFont(AppFont.buttonM)
                                .foregroundColor(Color("Neutral-500"))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(Color("Neutral-900").clipShape(RoundedRectangle(cornerRadius: 10)))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteInvite(inviteId: invite.id) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(totalCount) * rowHeight)
            }
        }
    }

    // MARK: - Invite action buttons
    private var inviteActions: some View {
        VStack(alignment: .leading, spacing: 10) {
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

    // MARK: - Emoji Setup section

    private var emojiSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Emoji Setup")

            switch viewModel.emojiRule {
            case .selectedOnly:
                selectedOnlyEmojiGrid
            case .anyEmoji:
                anyEmojiSelector
            }
        }
    }

    private var selectedOnlyEmojiGrid: some View {
        let rows = editEmojiRows
        return VStack(spacing: 32) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 32) {
                    ForEach(0..<5, id: \.self) { index in
                        if index < row.count {
                            let item = row[index]
                            switch item {
                            case .emoji(let value):
                                Text(value)
                                    .font(.system(size: 36))
                                    .frame(width: 36, height: 36)
                        case .add:
                            Button { isEmojiKeyboardFocused = true } label: {
                                Image("emojiSetupEdit")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Color.clear
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var anyEmojiSelector: some View {
        Button { isEmojiKeyboardFocused = true } label: {
            if let emoji = viewModel.presetEmojis.first, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 56))
                    .frame(width: 72, height: 72)
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color("Neutral-800")))
            }
        }
        .buttonStyle(.plain)
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
                    .appFont(AppFont.buttonL)
                    .foregroundColor(viewModel.isSaveEnabled ? Color("Neutral-1000") : Color("Neutral-600"))
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
        HStack(spacing: 12) {
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
        .padding(.horizontal, 12)
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
                Text(title).appFont(AppFont.labelM)
            }
            .foregroundColor(Color("White"))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color("Neutral-900"))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showBorder ? Color("Neutral-700") : Color.clear, style: StrokeStyle(lineWidth: 1, dash: isDashed ? [6, 6] : []))
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

    private var editEmojiRows: [[EditEmojiItem]] {
        var items = viewModel.presetEmojis.map(EditEmojiItem.emoji)
        if viewModel.canAddEmoji {
            items.append(.add)
        }

        var rows: [[EditEmojiItem]] = []
        var remaining = items[...]
        while !remaining.isEmpty {
            let take = min(5, remaining.count)
            rows.append(Array(remaining.prefix(take)))
            remaining = remaining.dropFirst(take)
        }
        return rows
    }
}

private extension EditChallengeView {
    enum EditEmojiItem: Hashable {
        case emoji(String)
        case add
    }
}

#Preview {
    EditChallengeView(challengeId: UUID())
}
