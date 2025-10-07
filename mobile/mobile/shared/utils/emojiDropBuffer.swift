import Foundation

final class PendingEmojiDropStore {
    static let shared = PendingEmojiDropStore()
    private var friendIdToEmojis: [String: [String]] = [:]
    private let lock = NSLock()

    func enqueue(friendId: String, emoji: String) {
        lock.lock(); defer { lock.unlock() }
        friendIdToEmojis[friendId, default: []].append(emoji)
    }

    func drain(for friendId: String) -> [String] {
        lock.lock(); defer { lock.unlock() }
        let items = friendIdToEmojis[friendId] ?? []
        friendIdToEmojis[friendId] = []
        return items
    }
}

// Buffer for text-note presence while jar is hidden
final class PendingNoteStore {
    static let shared = PendingNoteStore()
    private var pendingFriendIds: Set<String> = []
    private let lock = NSLock()

    func markPending(for friendId: String) {
        lock.lock(); defer { lock.unlock() }
        pendingFriendIds.insert(friendId)
    }

    func consume(for friendId: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let had = pendingFriendIds.contains(friendId)
        pendingFriendIds.remove(friendId)
        return had
    }
}


