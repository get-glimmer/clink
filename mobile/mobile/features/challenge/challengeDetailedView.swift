import SwiftUI
import SpriteKit
import UIKit

struct ChallengeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChallengeDetailViewModel

    @State private var selectedProofTaskId: UUID?
    @State private var selectedProofImage: UIImage?
    @State private var showProofSourceDialog = false
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var showAllParticipants = false
    @State private var showGallerySheet = false
    @State private var showAllCommentsSheet = false
    @State private var jarRemountToken = UUID()
    @State private var showEditChallenge = false
    @State private var showResult = false

    var onBack: (() -> Void)?
    var onTapFavorite: (() -> Void)?

    init(
        challengeId: UUID,
        onBack: (() -> Void)? = nil,
        onTapFavorite: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: ChallengeDetailViewModel(challengeId: challengeId))
        self.onBack = onBack
        self.onTapFavorite = onTapFavorite
    }

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.textWhite))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
                            .padding(.top, 8)

                        jarSection

                        challengeInfoSection

                        overallProgressSection

                        weeklyProgressSection

                        todaysTaskSection
                        
                        participantsSection
                        
                        if viewModel.isPhotoProofEnabled {
                            gallerySection
                        }
                        
                        communitySupportSection
                            .padding(.bottom, 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.jarItems.count) { count in
            // Force remount only when jar should become empty.
            if count == 0 {
                jarRemountToken = UUID()
            }
        }
        .confirmationDialog("Add Proof Photo", isPresented: $showProofSourceDialog, titleVisibility: .visible) {
            Button("Take Photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCameraPicker = true
                } else {
                    showPhotoLibraryPicker = true
                }
            }
            Button("Choose from Library") {
                showPhotoLibraryPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCameraPicker) {
            ChallengeImagePicker(sourceType: .camera, selectedImage: $selectedProofImage)
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            ChallengeImagePicker(sourceType: .photoLibrary, selectedImage: $selectedProofImage)
        }
        .onChange(of: selectedProofImage) { image in
            guard let image, let taskId = selectedProofTaskId else { return }
            Task {
                await viewModel.uploadProofImage(taskId: taskId, image: image)
                await MainActor.run {
                    selectedProofImage = nil
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showGallerySheet) {
            FullGallerySheet(items: viewModel.galleryItems)
        }
        .sheet(isPresented: $showAllCommentsSheet) {
            FullCommunityCommentsSheet(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showEditChallenge) {
            EditChallengeView(challengeId: viewModel.challengeId)
        }
        .fullScreenCover(isPresented: $showResult) {
            ChallengeResultView(challengeId: viewModel.challengeId)
        }
        .onChange(of: showEditChallenge) { isShowing in
            if !isShowing { Task { await viewModel.load() } }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension ChallengeDetailView {
    var headerSection: some View {
        HStack {
            CircleIconButton(systemName: "chevron.left") {
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
            }

            Spacer()

            HStack(spacing: 10) {
                CircleIconButton(systemName: "pencil") {
                    showEditChallenge = true
                }

                CircleIconButton(systemName: "square.and.arrow.up") {
                    showResult = true
                }

                CircleIconButton(systemName: viewModel.isFavorite ? "star.fill" : "star") {
                    viewModel.isFavorite.toggle()
                    onTapFavorite?()
                }
            }
        }
    }

    var jarSection: some View {
        ChallengeJarView(
            jarItems: viewModel.jarItems,
            completionIsSealed: viewModel.isTodaySealed,
            storedIsCompleted: viewModel.todayShakerIsCompleted,
            lidColorStart: viewModel.todayLidColorStart,
            lidColorEnd: viewModel.todayLidColorEnd
        ) { start, end in
            Task {
                await viewModel.persistTodayShakerBecameSealed(start: start, end: end)
            }
        } onDidUnseal: {
            Task {
                await viewModel.persistTodayShakerBecameUnsealed()
            }
        }
        .id(viewModel.jarItems.isEmpty ? "jar-empty-\(jarRemountToken.uuidString)" : "jar-active")
        .frame(height: 380)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var challengeInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.dateRangeText)
                .foregroundColor(AppColors.neutral1000)
                .appText(AppFont.labelS)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.green300)
                .cornerRadius(999)

            Text(viewModel.title)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.title1)

            Text(viewModel.description)
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.body2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var overallProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Overall Progress")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelM)
                Spacer()
                Text("\(Int((viewModel.overallProgress * 100).rounded()))%")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelM)
            }

            ProgressBar(value: viewModel.overallProgress)

            HStack {
                Spacer()
                Text(viewModel.dayIndexText)
                    .foregroundColor(AppColors.neutral300)
                    .appText(AppFont.captionS)
            }
        }
        .padding(.top, 6)
    }

    var weeklyProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Progress")
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelM)

            HStack(spacing: 0) {
                ForEach(viewModel.weekly) { day in
                    WeeklyDayCell(day: day)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    var todaysTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Task")
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.labelM)

            VStack(spacing: 16) {
                ForEach(viewModel.todayTasks) { task in
                    TodayTaskRow(
                        title: task.title,
                        isCompleted: task.isCompleted,
                        hasProof: task.hasProof,
                        proofURL: task.proofURL,
                        onToggle: {
                            viewModel.toggleTask(taskId: task.id)
                        },
                        showAddPhoto: viewModel.isPhotoProofEnabled,
                        onTapAddPhoto: {
                            selectedProofTaskId = task.id
                            showProofSourceDialog = true
                        }
                    )
                }

                Button {
                    Task { await viewModel.submitTodayChallenge() }
                } label: {
                    Text("Complete Day’s Challenge")
                        .foregroundColor(AppColors.textWhite)
                        .appText(AppFont.labelL)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.isCompleteDayButtonEnabled ? AppColors.green300 : AppColors.neutral600)
                        .cornerRadius(8)
                }
                .disabled(!viewModel.isCompleteDayButtonEnabled)
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(AppColors.neutral900)
            .cornerRadius(16)
        }
        .padding(.top, 6)
    }
    
    var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Participants")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelM)
                Text("\(viewModel.participants.count)")
                    .foregroundColor(AppColors.green300)
                    .appText(AppFont.labelM)
                
                Spacer()
                
                if viewModel.participants.count > 3 {
                    Button(showAllParticipants ? "Show less" : "View all") {
                        showAllParticipants.toggle()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.green300)
                    .appText(AppFont.buttonM)
                }
            }
            
            let shown = showAllParticipants ? viewModel.participants : Array(viewModel.participants.prefix(3))
            let topDays = viewModel.participants.map(\.joinedDays).max() ?? 0
            ForEach(shown) { participant in
                ParticipantRow(
                    participant: participant,
                    showCrown: participant.joinedDays == topDays && topDays > 0
                )
            }
        }
        .padding(.top, 6)
    }
    
    var gallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gallery")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.labelM)
                
                Spacer()
                
                Button("View all") {
                    showGallerySheet = true
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.green300)
                .appText(AppFont.buttonM)
            }
            
            if viewModel.galleryItems.isEmpty {
                Text("No proof photos yet.")
                    .foregroundColor(AppColors.neutral400)
                    .appText(AppFont.captionM)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.galleryItems.prefix(4))) { item in
                        GalleryThumb(imageURL: item.imageURL)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 6)
    }
    
    var communitySupportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Community Support")
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.buttonM)

                Spacer()

                Button("View all") {
                    showAllCommentsSheet = true
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.green300)
                .appText(AppFont.buttonM)
            }

            if viewModel.communityComments.isEmpty {
                Text("No comments yet. Leave encouragement first.")
                    .foregroundColor(AppColors.neutral400)
                    .appText(AppFont.captionM)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(viewModel.communityComments.prefix(2))) { item in
                    CommunityCommentRow(item: item)
                }
            }

            CommunityComposerRow(
                avatarURL: viewModel.currentUserAvatarURL,
                text: $viewModel.commentDraft,
                isSending: viewModel.isSendingComment
            ) {
                Task {
                    await viewModel.submitComment()
                }
            }
        }
        .padding(.top, 6)
    }

}

private struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textWhite)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.neutral800)
                Capsule()
                    .fill(AppColors.green300)
                    .frame(width: max(0, geo.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: 10)
    }
}

private struct WeeklyDayCell: View {
    let day: WeeklyDayUI

    var body: some View {
        VStack(spacing: 6) {
            Text(day.weekday)
                .foregroundColor(AppColors.neutral400)
                .appText(AppFont.captionXS)

            WeeklyShakerStatusIcon(
                isChallengeDay: day.isChallengeDay,
                isCompleted: day.isCompleted,
                lidColorStart: day.lidColorStart,
                lidColorEnd: day.lidColorEnd
            )
            .frame(width: 28.3, height: 28.14)

            Text(day.day)
                .foregroundColor(day.isToday ? AppColors.neutral1000 : AppColors.neutral400)
                .appText(AppFont.captionS)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(day.isToday ? AppColors.green300 : Color.clear)
                .cornerRadius(999)
        }
    }
}

private struct WeeklyShakerStatusIcon: View {
    let isChallengeDay: Bool
    let isCompleted: Bool
    let lidColorStart: String?
    let lidColorEnd: String?

    var body: some View {
        Group {
            if !isChallengeDay {
                Image("challengeNoTask")
                    .resizable()
                    .scaledToFit()
            } else if isCompleted {
                ZStack {
                    Image("challengeCompleted")
                        .resizable()
                        .scaledToFit()

                    lidOverlay
                }
            } else {
                Image("challengeNotCompleted")
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    @ViewBuilder
    private var lidOverlay: some View {
        if let c0 = Color(hex: lidColorStart), let c1 = Color(hex: lidColorEnd) {
            LinearGradient(colors: [c0, c1], startPoint: .leading, endPoint: .trailing)
                .mask(
                    Image("challengeCompletedLid")
                        .resizable()
                        .scaledToFit()
                )
        } else {
            Image("challengeCompletedLid")
                .resizable()
                .scaledToFit()
        }
    }
}

private struct TodayTaskRow: View {
    let title: String
    let isCompleted: Bool
    let hasProof: Bool
    let proofURL: String?
    let onToggle: () -> Void

    let showAddPhoto: Bool
    let onTapAddPhoto: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                Image(isCompleted ? "checkboxFilled" : "checkboxEmpty")
                    .foregroundColor(.primary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            Text(title)
                .foregroundColor(AppColors.textWhite)
                .appText(AppFont.body1)
                .strikethrough(isCompleted, color: AppColors.neutral400)
                .padding(.leading, 15)

            Spacer()

            if showAddPhoto {
                Button(action: { onTapAddPhoto?() }) {
                    Group {
                        if let proofURL,
                           let url = URL(string: proofURL),
                           hasProof {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Image("addPhoto")
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                        } else {
                            Image("addPhoto")
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .id(proofURL ?? "addPhoto")
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct ParticipantRow: View {
    let participant: ChallengeParticipantUI
    let showCrown: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.neutral900)
                    .frame(width: 40, height: 40)
                Text(participant.emoji)
                    .font(.system(size: 22))
            }
            
            HStack(spacing: 6) {
                Text(participant.name)
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.captionM)
                if showCrown {
                    Image("challengeCrown")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 10)
                }
            }
            
            Spacer()
            
            Text("\(participant.joinedDays) day\(participant.joinedDays == 1 ? "" : "s")")
                .foregroundColor(AppColors.neutral300)
                .appText(AppFont.captionM)
                .frame(width: 63, height: 26)
                .background(AppColors.neutral900)
                .cornerRadius(8)
        }
    }
}

private struct GalleryThumb: View {
    let imageURL: String

    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.neutral900)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(AppColors.neutral400)
                    )
            }
        }
        .frame(width: 89, height: 89)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FullGallerySheet: View {
    let items: [ChallengeGalleryItemUI]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(items) { item in
                        GalleryThumb(imageURL: item.imageURL)
                    }
                }
                .padding(16)
            }
            .background(AppColors.neutral1000)
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct FullCommunityCommentsSheet: View {
    @ObservedObject var viewModel: ChallengeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeleteCommentId: Int64?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            AppColors.neutral1000.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textWhite)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Community")
                        .foregroundColor(AppColors.textWhite)
                        .appText(AppFont.title2)

                    Spacer()

                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.communityComments) { item in
                            CommunityCommentRow(
                                item: item,
                                showDelete: viewModel.isMyComment(item),
                                onDelete: {
                                    pendingDeleteCommentId = item.id
                                    showDeleteConfirm = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColors.neutral800)
                        .frame(height: 1)

                    CommunityComposerRow(
                        avatarURL: viewModel.currentUserAvatarURL,
                        text: $viewModel.commentDraft,
                        isSending: viewModel.isSendingComment
                    ) {
                        Task {
                            await viewModel.submitComment()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColors.neutral1000)
                }
            }
        }
        .confirmationDialog(
            "Delete this comment?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let id = pendingDeleteCommentId else { return }
                Task {
                    await viewModel.deleteComment(commentId: id)
                }
                pendingDeleteCommentId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteCommentId = nil
            }
        }
    }
}

private struct CommentAvatarView: View {
    let avatarURL: String?

    var body: some View {
        Group {
            if let avatarURL,
               let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle()
                            .fill(AppColors.neutral900)
                    }
                }
            } else {
                Circle()
                    .fill(AppColors.neutral900)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
}

private struct CommunityCommentRow: View {
    let item: ChallengeCommentUI
    var showDelete: Bool = false
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CommentAvatarView(avatarURL: item.commenterAvatarURL)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.comment)
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.body2)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(AppColors.neutral900)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    HStack(spacing: 8) {
                        Text(item.commenterName)
                            .foregroundColor(AppColors.neutral400)
                            .appText(AppFont.captionXS_M)
                        Text("·")
                            .foregroundColor(AppColors.neutral400)
                            .appText(AppFont.captionXS_M)
                        Text(item.relativeTimeText)
                            .foregroundColor(AppColors.neutral400)
                            .appText(AppFont.captionXS_M)
                    }
                    Spacer()
                    if showDelete {
                        Button("Delete") {
                            onDelete?()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color("Red-300"))
                        .appText(AppFont.buttonM)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}

private struct CommunityComposerRow: View {
    let avatarURL: String?
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CommentAvatarView(avatarURL: avatarURL)

            HStack(spacing: 10) {
                TextField("Add encouragement...", text: $text)
                    .foregroundColor(AppColors.textWhite)
                    .appText(AppFont.body2)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend {
                            onSend()
                        }
                    }

                Button(action: onSend) {
                    Image("paperPlane")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 14)
                        .opacity(canSend ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(AppColors.neutral900)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.neutral800, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
}

private struct ChallengeImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ChallengeImagePicker

        init(parent: ChallengeImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
    }
}

struct ChallengeJarView: View {
    let jarItems: [JarItemUI]
    let completionIsSealed: Bool
    let storedIsCompleted: Bool
    let lidColorStart: String?
    let lidColorEnd: String?
    let onDidSeal: ((String, String) -> Void)?
    let onDidUnseal: (() -> Void)?

    @State private var scene = ShakerScene(size: .zero)
    @State private var didConfigure = false
    @State private var previousCompletionIsSealed: Bool = false

    private let lidHeightRatio: CGFloat = 46.0 / 270.0
    private let lidCornerRatio: CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio: CGFloat = 23.5 / 270.0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)

            ZStack {
                Image("jarBase")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(lidGradient)
                    .frame(width: jarSize.width, height: jarSize.height * lidHeightRatio)
                    .cornerRadius(jarSize.height * lidCornerRatio)
                    .offset(y: -jarSize.height / 2 + jarSize.height * lidTopInsetRatio)
                    .opacity(shouldShowLid ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: shouldShowLid)
                    .allowsHitTesting(false)

                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)

                Image("glitchLid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .onAppear {
                if scene.size == .zero {
                    scene = ShakerScene(size: jarSize)
                }

                scene.setEmojiScale(1.0)
                scene.setMotionEnabled(true)
                scene.configureBoundaries(inset: 12, lidHeight: 40)
                scene.setHapticsEnabled(false)

                syncJarItemsToScene()
                previousCompletionIsSealed = completionIsSealed
                didConfigure = true
            }
            .onChange(of: jarItems.map { "\($0.id.uuidString):\($0.emoji)" }.joined(separator: ",")) { _ in
                guard didConfigure else { return }
                syncJarItemsToScene()
            }
            .onChange(of: completionIsSealed) { newValue in
                let didTransitionToSealed = !previousCompletionIsSealed && newValue
                let didTransitionToUnsealed = previousCompletionIsSealed && !newValue
                previousCompletionIsSealed = newValue

                if didTransitionToSealed {
                    let extracted = gradientFromScene()
                    let h0 = UIColor(extracted[0]).toHex()
                    let h1 = UIColor(extracted[1]).toHex()
                    onDidSeal?(h0, h1)
                } else if didTransitionToUnsealed {
                    onDidUnseal?()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func syncJarItemsToScene() {
        scene.resetScene()
        for item in jarItems {
            scene.addEmoji(item.emoji, for: item.id)
        }
    }

    private var lidGradient: LinearGradient {
        let colors: [Color]
        if let c0 = Color(hex: lidColorStart), let c1 = Color(hex: lidColorEnd) {
            colors = [c0, c1]
        } else {
            colors = [Color.clear, Color.clear]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private var shouldShowLid: Bool {
        storedIsCompleted && Color(hex: lidColorStart) != nil && Color(hex: lidColorEnd) != nil
    }

    private func gradientFromScene() -> [Color] {
        let ui = scene.marbleDominantColors(maxCount: 6)
        guard let first = ui.first else {
            return [AppColors.green300, AppColors.green300.opacity(0.7)]
        }

        let threshold: CGFloat = 0.18
        if let distinct = ui.dropFirst().first(where: {
            $0.perceptualDistance(to: first) >= threshold
        }) {
            return [Color(first), Color(distinct)]
        }

        if ui.count >= 2 { return ui.prefix(2).map { Color($0) } }
        if ui.count == 1 {
            let c = Color(first)
            return [c, c.opacity(0.7)]
        }
        return [AppColors.green300, AppColors.green300.opacity(0.7)]
    }
}

private extension UIColor {
    var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }

    func perceptualDistance(to other: UIColor) -> CGFloat {
        let lhs = self.hsba
        let rhs = other.hsba
        let dh = abs(lhs.h - rhs.h)
        let hueDist = min(dh, 1 - dh)
        let satDist = abs(lhs.s - rhs.s)
        return hueDist * 0.7 + satDist * 0.3
    }
}
