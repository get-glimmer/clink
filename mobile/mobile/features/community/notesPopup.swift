import SwiftUI

// MARK: - Notes Popup View
struct NotesPopupView: View {
    let friend: Friend
    @State private var notes: [NoteRecord] = []
    @State private var isLoading: Bool = true
    @StateObject private var communityService = CommunityService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Main popup content
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    Text("Notes for \(friend.name)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.neutral800)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.neutral600)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Notes content
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2)
                        Text("Loading notes...")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.neutral600)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else if notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.neutral400)
                        Text("No notes yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.neutral600)
                        Text("Be the first to leave a note for \(friend.name)!")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.neutral500)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notes) { note in
                                NoteCardView(note: note)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(width: 350, height: 450)
            .background(Color.white)
            .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear { loadNotes() }
    }
    
    private func loadNotes() {
        Task {
            isLoading = true
            do {
                if let shakerId = try await communityService.getCurrentShakerForUser(userId: friend.userId, date: Date()) {
                    // Load notes for this shaker and pick ONE random text note
                    let loadedNotes = try await communityService.getNotesForShaker(shakerId: shakerId, limit: 20)
                    await MainActor.run {
                        let textNotes = loadedNotes.filter { !$0.noteContent.isEmojiOnly }
                        notes = textNotes.randomElement().map { [$0] } ?? []
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        notes = []
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    notes = []
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Note Card View
struct NoteCardView: View {
    let note: NoteRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.noteContent)
                .font(.system(size: 15))
                .foregroundColor(AppColors.neutral800)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Text(timeAgoString(from: note.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.neutral500)
            }
        }
        .padding(16)
        .background(AppColors.neutral100)
        .cornerRadius(12)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


