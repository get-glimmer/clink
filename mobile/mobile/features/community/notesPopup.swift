import SwiftUI

// MARK: - Notes Popup View
struct NotesPopupView: View {
    let friend: Friend
    let initialNoteId: UUID?
    let initialNoteContent: String?
    let initialNote: NoteRecord?
    let date: Date
    @State private var notes: [NoteRecord] = []
    @State private var isLoading: Bool = true
    @StateObject private var communityService = CommunityService()
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var authorNames: [UUID: String] = [:]
    
    var body: some View {
        ZStack {
            // Background: dark blur + dim for consistency with other overlays
            ZStack {
                DarkBlurView(style: .systemUltraThinMaterialDark)
                    .ignoresSafeArea()
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
            }
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
            
            // Main popup content: stacked sticky notes with paging
            GeometryReader { geo in
                let cardW: CGFloat = 320
                let cardH: CGFloat = 320
                let colors: [Color] = [
                    Color(red: 1.00, green: 0.96, blue: 0.66), // yellow
                    Color(red: 1.00, green: 0.89, blue: 0.74), // peach
                    Color(red: 0.79, green: 0.90, blue: 0.98), // blue
                    Color(red: 0.92, green: 0.86, blue: 0.96)  // purple
                ]
                ZStack {
                    // Close button (top-right)
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 27, weight: .light))
                                    .foregroundColor(AppColors.neutral400)
                                    .frame(width: 44, height: 44)
                            }
                            .padding(.top, 30)
                            .padding(.trailing, 16)
                        }
                        Spacer()
                    }
                    
                    // Stack of notes
                    ZStack {
                        // back layers (decorative sheets)
                        Rectangle()
                            .fill(colors[(currentIndex + 2) % colors.count].opacity(0.9))
                            .frame(width: cardW * 0.98, height: cardH * 0.98)
                            .rotationEffect(.degrees(-6))
                            .offset(x: -12, y: -8)
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                        Rectangle()
                            .fill(colors[(currentIndex + 1) % colors.count].opacity(0.95))
                            .frame(width: cardW, height: cardH)
                            .rotationEffect(.degrees(6))
                            .offset(x: 12, y: 8)
                            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                        
                        // front note
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView().scaleEffect(1.2)
                                Text("Loading notes...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                            .frame(width: cardW, height: cardH)
                            .background(colors[currentIndex % colors.count])
                            .cornerRadius(2)
                        } else if notes.isEmpty {
                            VStack(spacing: 10) {
                                Text("No notes yet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.8))
                                Text("Be the first to leave a note for \(friend.name)!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black.opacity(0.6))
                            }
                            .frame(width: cardW, height: cardH)
                            .background(colors[currentIndex % colors.count])
                            .cornerRadius(2)
                        } else {
                            let note = notes[currentIndex % notes.count]
                            VStack {
                                HStack {
                                    Text(note.noteContent)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.9))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer(minLength: 0)
                                }
                                Spacer()
                                HStack {
                                    // Emoji bottom-left when present
                                    if let emoji = note.noteEmoji, !emoji.isEmpty {
                                        Text(emoji)
                                            .font(.system(size: 60))
                                            .frame(width: 60, height: 60, alignment: .leading)
                                    }
                                    Spacer()
                                    Text("– \(authorNames[note.userId] ?? "Someone")")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                            .frame(width: cardW, height: cardH)
                            .background(colors[currentIndex % colors.count])
                            .cornerRadius(2)
                            .gesture(
                                DragGesture(minimumDistance: 20)
                                    .onEnded { value in
                                        if value.translation.width < -30 {
                                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex + 1) % max(notes.count, 1) }
                                        } else if value.translation.width > 30 {
                                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex - 1 + notes.count) % max(notes.count, 1) }
                                        }
                                    }
                            )
                        }
                    }
                    .frame(width: cardW, height: cardH)
                    
                    // Right paging arrow
                    if !isLoading && !notes.isEmpty && notes.count > 1 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex + 1) % notes.count }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.neutral1000)
                            }
                        }
                        .buttonStyle(.plain)
                        .position(x: geo.size.width - 38, y: geo.size.height / 2) // 22pt from right edge (circle radius 16)
                    }
                    
                    // Left paging arrow
                    if !isLoading && !notes.isEmpty && notes.count > 1 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { currentIndex = (currentIndex - 1 + notes.count) % notes.count }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.neutral1000)
                            }
                        }
                        .buttonStyle(.plain)
                        .position(x: 38, y: geo.size.height / 2) // 22pt from left edge (circle radius 16)
                    }
                    
                    // Dots indicator
                    if !isLoading && !notes.isEmpty && notes.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<notes.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .position(x: geo.size.width / 2, y: (geo.size.height + cardH) / 2 + 36)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear { loadNotes() }
    }
    
    private func loadNotes() {
        Task {
            isLoading = true
            do {
                if let shakerId = try await communityService.getCurrentShakerForUser(userId: friend.userId, date: date) {
                    // Load enough to include the tapped note
                    let loadedNotes = try await communityService.getNotesForShaker(shakerId: shakerId, limit: 100)
                    await MainActor.run {
                        let textNotes = loadedNotes.filter { !$0.noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        // Restore multiple notes (up to 10), no special reordering
                        notes = Array(textNotes.prefix(10))
                        Task { await loadAuthorNames(for: notes.map { $0.userId }) }
                        currentIndex = 0
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
    
    // Load display names for note authors
    private func loadAuthorNames(for userIds: [UUID]) async {
        guard let client = SupabaseClientManager.shared.client else { return }
        let unique = Array(Set(userIds))
        guard !unique.isEmpty else { return }
        struct Row: Decodable {
            let id: String
            let name: String?
            let username: String?
        }
        do {
            let rows: [Row] = try await client
                .from("profiles")
                .select("id,name,username")
                .in("id", value: unique.map { $0.uuidString })
                .execute()
                .value
            var map: [UUID: String] = [:]
            for r in rows {
                let displayName = [r.username, r.name]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }
                if let uuid = UUID(uuidString: r.id), let displayName {
                    map[uuid] = displayName
                }
            }
            await MainActor.run { authorNames.merge(map) { _, new in new } }
        } catch {
            // ignore lookup failures
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


