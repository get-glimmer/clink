//
//  shakerView.swift
//  mobile
//
//  Created by 이채린 on 7/21/25.
//

import SwiftUI
import SpriteKit
import UIKit
import Supabase

struct ShakerView: View {
    // External state
    @ObservedObject var viewModel: TaskListViewModel
    
    // externally tell this view whether it is actually visible/active
    var isActive: Bool = true
    
    // Optional callbacks
    var onNoteEmojiTapped: (() -> Void)? = nil
    
    // SpriteKit scene
    @State private var scene = ShakerScene(size: .zero)
    
    // Completion cache - add/remove marbles
    @State private var completionCache: [UUID: Bool] = [:]
    
    // store current emoji per completed task
    @State private var emojiCache: [UUID: String] = [:]
    // Track note emoji UUIDs (one per note)
    @State private var noteEmojiIds: Set<UUID> = []
    // Preview mode (small tile) flag
    @State private var isPreviewMode: Bool = false
    
    // Lid visuals
    @State private var lidColors: [Color] = [.black, .gray]
    @State private var lidOpacity: Double = 0
    // Lid position & size
    private let lidHeightRatio:      CGFloat = 46.0 / 270.0
    private let lidCornerRatio:      CGFloat = 13.0 / 270.0
    private let lidTopInsetRatio:    CGFloat = 23.5 / 270.0
    
    
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)
            
            ZStack {
                // --- Jar ---
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .allowsHitTesting(false)
                
                // --- Lid(Gradient) ---
                Rectangle()
                    .fill(
                        LinearGradient(colors: lidColors,
                                       startPoint: .leading,
                                       endPoint:   .trailing)
                    )
                    .frame(
                        width: jarSize.width,
                        height: jarSize.height * lidHeightRatio
                    )
                    .cornerRadius(jarSize.height * lidCornerRatio)
                    .offset(
                        y: -jarSize.height / 2                // jar top
                        + jarSize.height * lidTopInsetRatio
                    )
                    .opacity(lidOpacity)
                    .animation(.easeInOut(duration: 0.25), value: lidOpacity)
                    .allowsHitTesting(false)
                
                // --- Physics(canvas) ---
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .frame(width: jarSize.width, height: jarSize.height)
            }
            // Center the jar inside available space (preview tiles especially)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .onAppear {
                if scene.size == .zero { // create a new scene only once
                        scene = ShakerScene(size: jarSize)
                    }
                // Wire note tap callback (if provided)
                scene.onNotesEmojiTapped = onNoteEmojiTapped
                // If height is small (preview), scale emoji down and use constant gravity (no device motion)
                let isPreview = jarSize.height <= 150
                isPreviewMode = isPreview
                scene.setEmojiScale(isPreview ? 0.75 : 1.0)
                scene.setMotionEnabled(!isPreview)
                if isPreview {
                    // Lower the floor a bit to avoid floating look in tight previews
                    scene.configureBoundaries(inset: 12, lidHeight: 40, bottomExtraDepth: 20)
                    // Stronger constant gravity so marbles settle firmly at the bottom
                    scene.useConstantGravity(18)
                } else {
                    // Reset to default boundaries for full view
                    scene.configureBoundaries(inset: 12, lidHeight: 40)
                }
                
                // haptic off when isPreview
                scene.setHapticsEnabled(!isPreview && isActive)
                
                // Clear any previous contents to avoid duplicates across re-entries
                scene.resetScene()
                noteEmojiIds.removeAll()
                completionCache.removeAll()
                syncWithTasks()
                updateSeal(animated: false)
                Task { await syncNoteEmoji() }
                // Drain any pending reaction emojis queued while jar was hidden
                if let owner = viewModel.ownerUserId {
                    let pending = PendingEmojiDropStore.shared.drain(for: owner)
                    for e in pending {
                        scene.addGlowingEmoji(e, for: UUID())
                    }
                    if isPreviewMode { scene.settleAllToBottom() }
                }
                // Also ensure current liked categories are reflected when the jar remounts
                Task { await addLikedCategoryEmojisToShaker() }
            }
            .onDisappear {
                scene.setMotionEnabled(false) // for performance
                scene.setHapticsEnabled(false)
            }
            .onChange(of: geo.size) { _ in
                // On size changes (preview tiles) ensure marbles snap to floor
                let isPreview = min(geo.size.width, geo.size.height) <= 150
                if isPreview {
                    scene.settleAllToBottom()
                }
            }
        }
        .onReceive(viewModel.$categoriesWithTasks) { _ in
            syncWithTasks()
            // Also reflect already-liked categories as glowing emojis when data arrives/changes
            Task { await addLikedCategoryEmojisToShaker() }
        }
        .onChange(of: viewModel.emojiForDate) { _ in syncWithTasks()
            // isAllCompleted 였다면 이모지 변경에 따라 기존 뚜껑색 변경 유도.
            viewModel.lidColorStart = nil
            viewModel.lidColorEnd = nil
        }
        .onReceive(viewModel.$isAllCompleted)      { _ in syncWithTasks()
            updateSeal(animated: true)
        }
        .onChange(of: viewModel.taskSelectedDate) { newDate in
            syncWithTasks()
            UnsealLidAndUpdate()
            Task { await syncNoteEmoji() }
        }
        .onChange(of: isActive) { active in
            // Only enable when not preview
            let enableHaptics = (!isPreviewMode && active)
            scene.setHapticsEnabled(enableHaptics)
        }
        // Listen for like/unlike reactions and reflect in this shaker if the userId matches
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionAdded)) { output in
            guard let owner = viewModel.ownerUserId,
                  let info = output.userInfo,
                  let target = info["friendUserId"] as? String,
                  let emoji  = info["emoji"] as? String,
                  target == owner else { return }
            if !scene.hasReactionEmoji(emoji) {
                scene.addGlowingEmoji(emoji, for: UUID())
                if isPreviewMode { scene.settleAllToBottom() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionRemoved)) { output in
            guard let owner = viewModel.ownerUserId,
                  let info = output.userInfo,
                  let target = info["friendUserId"] as? String,
                  let emoji  = info["emoji"] as? String,
                  target == owner else { return }
            scene.removeReactionEmoji(symbol: emoji)
            if isPreviewMode { scene.settleAllToBottom() }
        }
        // Listen for note-added events and show the note emoji immediately
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerNoteAdded)) { output in
            guard let owner = viewModel.ownerUserId,
                  let info = output.userInfo,
                  let target = info["friendUserId"] as? String,
                  target == owner else { return }
            // Add one note emoji when a new note is submitted
            let id = UUID()
            noteEmojiIds.insert(id)
            scene.addEmoji("🗒️", for: id)
            if isPreviewMode { scene.settleAllToBottom() }
        }
    }
    
    // MARK: - Marble Syncing
    private func syncWithTasks() {
        // If scene was cleared (ex. size changed), clear caches as well
        if completionCache.isEmpty == false && scene.children.isEmpty {
            completionCache.removeAll()
            emojiCache.removeAll() // NEW
        }

        // Build current state: (completed?, emoji-for-selected-date)
        var current: [UUID: (Bool, String)] = [:]
        for cat in viewModel.categoriesWithTasks {
            for task in cat.tasks {
                let emj = viewModel.emojiFor(
                    categoryId: cat.category.id,
                    defaultEmoji: cat.category.emoji
                )
                current[task.id] = (task.isCompleted, emj)
            }
        }

        // 1) Update emoji of marbles that remain completed, if the emoji changed
        for (id, info) in current where info.0 && completionCache[id] == true {
            let oldEmoji = emojiCache[id]
            if oldEmoji != info.1 {
                scene.updateEmoji(info.1, for: id)
                emojiCache[id] = info.1
            }
        }

        // 2) Add newly completed marbles
        for (id, info) in current where info.0 && completionCache[id] != true {
            scene.addEmoji(info.1, for: id)
            emojiCache[id] = info.1
        }

        // 3) Remove marbles that are no longer completed
        for (id, wasCompleted) in completionCache where wasCompleted && current[id]?.0 != true {
            scene.removeEmoji(for: id)
            emojiCache.removeValue(forKey: id)
        }

        // 4) Refresh caches
        completionCache = current.mapValues { $0.0 }

        // Prune emojiCache to only keep currently completed tasks
        let valid = Set(current.keys.filter { current[$0]?.0 == true })
        emojiCache = emojiCache.filter { valid.contains($0.key) }
        if isPreviewMode { scene.settleAllToBottom() }
    }

    
    // MARK: - Seal / Unseal
    private func updateSeal(animated: Bool) {
        if viewModel.isAllCompleted {
            // DB에 저장된 색상이 있다면 우선 사용
            if let c0 = Color(hex: viewModel.lidColorStart),
               let c1 = Color(hex: viewModel.lidColorEnd) {
                lidColors = [c0, c1]
            } else {
                // 첫 seal → 마블에서 추출 후 DB 저장
                lidColors = gradientFromScene()
                Task {
                    let h0 = UIColor(lidColors[0]).toHex()
                    let h1 = UIColor(lidColors[1]).toHex()
                    await viewModel.updateShakerLidColors(start: h0, end: h1)
                }
            }
            withAnimation(animated ? .easeInOut(duration: 0.3) : nil) {
                lidOpacity = 1
            }
        } else {
            viewModel.lidColorStart = nil
            viewModel.lidColorEnd   = nil
            
            withAnimation(animated ? .easeInOut(duration: 0.25) : nil) {
                lidOpacity = 0
            }
        }
    }

    // MARK: - Notes sync (drop one note emoji per text note)
    private func syncNoteEmoji() async {
        guard let owner = viewModel.ownerUserId else {
            print("🔴 syncNoteEmoji: no owner")
            return
        }
        guard let client = SupabaseClientManager.shared.client else {
            print("🔴 syncNoteEmoji: no client")
            return
        }
        let dateStr = formattedDate(viewModel.taskSelectedDate)
        print("📝 syncNoteEmoji: owner=\(owner), date=\(dateStr)")
        // Query shaker id for (owner, date)
        do {
            struct Row: Decodable { let id: String }
            let rows: [Row] = try await client
                .from("shaker").select("id")
                .eq("userid", value: owner)
                .eq("date", value: dateStr)
                .limit(1)
                .execute().value
            guard let shakerId = rows.first?.id else {
                print("📝 syncNoteEmoji: no shaker found")
                await MainActor.run { removeAllNoteEmojis() }
                return
            }
            print("📝 syncNoteEmoji: shakerId=\(shakerId)")
            // Fetch all notes for this shaker, then split into emoji-only vs text notes
            var textNotes: [NoteRecord] = []
            var emojiOnlySymbols: [String] = []
            if let shakerUUID = UUID(uuidString: shakerId) {
                do {
                    let loaded = try await CommunityService().getNotesForShaker(shakerId: shakerUUID, limit: 20)
                    for note in loaded {
                        print("📝 syncNoteEmoji: note content='\(note.noteContent)', isEmojiOnly=\(note.noteContent.isEmojiOnly)")
                    }
                    // Separate text vs emoji notes
                    textNotes = loaded.filter { !$0.noteContent.isEmojiOnly }
                    emojiOnlySymbols = loaded.compactMap { note in
                        note.noteContent.isEmojiOnly ? note.noteContent.firstEmoji : nil
                    }
                    print("📝 syncNoteEmoji: loaded \(loaded.count) notes, \(textNotes.count) text notes, \(emojiOnlySymbols.count) emoji notes")
                } catch {
                    print("🔴 syncNoteEmoji: error loading notes - \(error)")
                    textNotes = []
                    emojiOnlySymbols = []
                }
            }

            // For emoji-only notes, ensure glowing reaction emojis are present on reload
            if !emojiOnlySymbols.isEmpty {
                await MainActor.run {
                    for symbol in emojiOnlySymbols {
                        // Avoid duplicate adds of the same reaction symbol
                        if !scene.hasReactionEmoji(symbol) {
                            scene.addGlowingEmoji(symbol, for: UUID())
                        }
                    }
                    if isPreviewMode { scene.settleAllToBottom() }
                }
            }
            if textNotes.isEmpty {
                print("📝 syncNoteEmoji: no text notes, removing all")
                await MainActor.run {
                    removeAllNoteEmojis()
                    if isPreviewMode { scene.settleAllToBottom() }
                }
            } else {
                print("📝 syncNoteEmoji: syncing \(textNotes.count) note emojis")
                await MainActor.run {
                    // Add one note emoji per text note
                    syncNoteEmojis(count: textNotes.count)
                    if isPreviewMode { scene.settleAllToBottom() }
                }
            }
        } catch {
            print("🔴 syncNoteEmoji: error - \(error)")
        }
    }

    private func syncNoteEmojis(count: Int) {
        let current = noteEmojiIds.count
        print("📝 syncNoteEmojis: current=\(current), target=\(count)")
        if count > current {
            // Add more note emojis
            for _ in 0..<(count - current) {
                let id = UUID()
                noteEmojiIds.insert(id)
                scene.addEmoji("🗒️", for: id)
                print("📝 Added note emoji with id=\(id)")
            }
        } else if count < current {
            // Remove excess note emojis
            let toRemove = current - count
            for id in noteEmojiIds.prefix(toRemove) {
                scene.removeEmoji(for: id)
                noteEmojiIds.remove(id)
                print("📝 Removed note emoji with id=\(id)")
            }
        }
    }
    
    private func removeAllNoteEmojis() {
        for id in noteEmojiIds {
            scene.removeEmoji(for: id)
        }
        noteEmojiIds.removeAll()
    }
    private func gradientFromScene() -> [Color] {
        // Grab up to 6 candidate colors
        let ui = scene.marbleDominantColors(maxCount: 6)
        guard let first = ui.first else { return [.black, .gray] }

        // Threshold: gives hue difference
        let threshold: CGFloat = 0.18

        // Find the first colour perceptually far enough from `first`
        if let distinct = ui.dropFirst().first(where: {
            $0.perceptualDistance(to: first) >= threshold
        }) {
            return [Color(first), Color(distinct)]
        }

        // Fallbacks: not enough variety
        if ui.count >= 2 { return ui.prefix(2).map { Color($0) } }
        if ui.count == 1  { let c = Color(first); return [c, c.opacity(0.7)] }
        return [.black, .gray]
    }
    
    private func UnsealLidAndUpdate() {
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            viewModel.isAllCompleted = false
        }
        updateSeal(animated: false)
    }

    // MARK: - Pre-populate reaction emojis for already-liked categories
    private func addLikedCategoryEmojisToShaker() async {
        guard let owner = viewModel.ownerUserId,
              let currentUserId = getUserId(),
              let userUUID = UUID(uuidString: currentUserId) else { return }
        let service = CommunityService()
        var added: Set<String> = []
        for categoryWithTasks in viewModel.categoriesWithTasks {
            let categoryId = categoryWithTasks.category.id
            do {
                let liked = try await service.isLiked(categoryId: categoryId, userId: userUUID)
                if liked {
                    let symbol = categoryWithTasks.category.emoji
                    if !added.contains(symbol) && !scene.hasReactionEmoji(symbol) {
                        added.insert(symbol)
                        await MainActor.run {
                            scene.addGlowingEmoji(symbol, for: UUID())
                            if isPreviewMode { scene.settleAllToBottom() }
                        }
                    }
                }
            } catch {
                // ignore
            }
        }
    }
}
// MARK: - Color helpers
private extension UIColor {
    // Returns HSBA components in 0‥1 range
    var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }

    // Quick perceptual distance (Hue + Saturation)
    func perceptualDistance(to other: UIColor) -> CGFloat {
        let lhs = self.hsba
        let rhs = other.hsba
        // Hue wrap-around handled via min(|Δh|, 1-|Δh|)
        let dh = abs(lhs.h - rhs.h)
        let hueDist = min(dh, 1 - dh)
        let satDist = abs(lhs.s - rhs.s)
        return hueDist * 0.7 + satDist * 0.3     // weighted
    }
}
