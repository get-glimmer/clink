//
//  FriendRequestRealtimeService.swift
//  mobile
//
//  Subscribes to Supabase Realtime Postgres changes on the "friends" table
//  so the pending-request badge updates instantly without polling.
//

import Foundation
import Supabase

@MainActor
final class FriendRequestRealtimeService: ObservableObject {

    @Published var pendingRequestCount: Int = 0

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var fallbackTimer: Timer?
    private var isSubscribed = false
    private var currentUserId: String?

    func start() async {
        guard !isSubscribed else { return }
        guard let userId = getUserId() else {
            return
        }
        currentUserId = userId
        guard let client = SupabaseClientManager.shared.client else {
            return
        }

        // 1) Fetch initial count
        await fetchPendingCount()

        // 2) Subscribe using the official docs API: client.channel()
        //    Listen to ALL changes on friends table (no server-side filter to
        //    avoid API-signature mismatches). We re-count from DB on every event.
        let ch = client.channel("friend-requests-\(userId)")

        let inserts = ch.postgresChange(InsertAction.self, table: "friends")
        let updates = ch.postgresChange(UpdateAction.self, table: "friends")
        let deletes = ch.postgresChange(DeleteAction.self, table: "friends")

        await ch.subscribe()
        channel = ch
        isSubscribed = true

        // 3) Consume events — any change on friends table triggers a re-count
        listenTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await action in inserts {
                        guard let self else { return }
                        await self.onChangeReceived()
                    }
                }
                group.addTask {
                    for await action in updates {
                        guard let self else { return }
                        await self.onChangeReceived()
                    }
                }
                group.addTask {
                    for await action in deletes {
                        guard let self else { return }
                        await self.onChangeReceived()
                    }
                }
            }
        }

        // 4) Slow fallback timer (every 60s) in case realtime misses an event
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchPendingCount()
            }
        }
    }

    func stop() async {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        listenTask?.cancel()
        listenTask = nil
        if let channel {
            await channel.unsubscribe()
        }
        channel = nil
        isSubscribed = false
    }

    // MARK: - Helpers

    private func onChangeReceived() async {
        await fetchPendingCount()
        NotificationCenter.default.post(name: .friendRequestsChanged, object: nil)
    }

    func fetchPendingCount() async {
        guard let client = SupabaseClientManager.shared.client,
              let userId = currentUserId ?? getUserId() else { return }

        do {
            let response = try await client
                .from("friends")
                .select("*", head: true, count: .exact)
                .eq("friend_id", value: userId)
                .eq("status", value: "requested")
                .execute()

            let newCount = response.count ?? 0
            if pendingRequestCount != newCount {
                pendingRequestCount = newCount
            }
        } catch {
        }
    }
}
