import SwiftUI
import SpriteKit

struct FriendShakerView: View {
    let friend: Friend
    @State private var scene: ShakerScene?
    
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let jarSize = CGSize(width: side, height: side)
            ZStack(alignment: .center) {
                Image("jar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: jarSize.width, height: jarSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
                if let scene = scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .frame(width: jarSize.width, height: jarSize.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(false)
                }
            }
            .onAppear { setupScene(jarSize: jarSize) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerNoteAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               friendUserId == friend.userId { addNoteEmojiToCard() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionAdded)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               let emoji = notification.userInfo?["emoji"] as? String,
               friendUserId == friend.userId { addGlowingEmojiToCard(emoji) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendShakerEmojiReactionRemoved)) { notification in
            if let friendUserId = notification.userInfo?["friendUserId"] as? String,
               let emoji = notification.userInfo?["emoji"] as? String,
               friendUserId == friend.userId { scene?.removeEmoji(symbol: emoji) }
        }
    }
    
    private func setupScene(jarSize: CGSize) {
        let sceneSize = CGSize(width: 400, height: 400)
        scene = ShakerScene(size: sceneSize)
        scene?.resetScene() // ensure clean state on appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for emoji in friend.emojis { scene?.addEmoji(emoji, for: UUID()) }
        }
        Task {
            do {
                if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId),
                   !(try await CommunityService().getNotesForShaker(shakerId: shakerId, limit: 1)).isEmpty {
                    await MainActor.run {
                        let noteEmoji = "🗒️"
                        if scene?.hasEmoji(noteEmoji) != true { scene?.addEmoji(noteEmoji, for: UUID()) }
                    }
                }
                if let shakerId = try await CommunityService().getCurrentShakerForUser(userId: friend.userId) {
                    let recent = try await CommunityService().getNotesForShaker(shakerId: shakerId, limit: 10)
                    let symbols = Array(Set(recent.compactMap { $0.noteContent.isEmojiOnly ? $0.noteContent.firstEmoji : nil })).prefix(5)
                    await MainActor.run {
                        for symbol in symbols { if scene?.hasEmoji(symbol) != true { scene?.addGlowingEmoji(symbol, for: UUID()) } }
                    }
                }
            } catch { }
        }
        scene?.setMotionEnabled(false)
    }
    private func addNoteEmojiToCard() { if scene?.hasEmoji("🗒️") != true { scene?.addEmoji("🗒️", for: UUID()) } }
    private func addGlowingEmojiToCard(_ emoji: String) { scene?.addGlowingEmoji(emoji, for: UUID()) }
}


