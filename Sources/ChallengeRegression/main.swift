import Foundation
import OddSockets

// Unbuffered stdout so progress is visible when piped to a file.
setvbuf(stdout, nil, _IONBF, 0)
FileHandle.standardError.write(Data("BOOT: harness started\n".utf8))

@MainActor
func log(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

// Two-client HONEST challenge regression against live QA.
//
// alice + bob: distinct userId, SAME apiKey (shared owner scope), both subscribe
// to 'lobby'. Exercises the worker v1.2 challenge/leaderboard/achievement/invite
// wire contract through the real Socket.IO transport.

// MARK: - Config / env

let apiKey = ProcessInfo.processInfo.environment["OS_KEY"] ?? ""
let managerUrl = ProcessInfo.processInfo.environment["ODDSOCKETS_MANAGER_URL"] ?? ""

guard !apiKey.isEmpty, !managerUrl.isEmpty else {
    FileHandle.standardError.write(Data("Missing OS_KEY or ODDSOCKETS_MANAGER_URL\n".utf8))
    exit(2)
}

let runId = String(UUID().uuidString.prefix(8)).lowercased()
let challengeId = "swiftchal_\(runId)"
let achievementId = "swiftach_\(runId)"
let room = "lobby"

// MARK: - Result tracking

@MainActor
final class Results {
    var pass = 0
    var fail = 0
    var lines: [String] = []

    func assert(_ name: String, _ cond: Bool, _ detail: String = "") {
        if cond {
            pass += 1
            lines.append("  PASS  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
        } else {
            fail += 1
            lines.append("  FAIL  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
        }
    }

    func note(_ s: String) { lines.append("  ....  \(s)") }
}

// MARK: - Event inbox (records raw broadcasts per client)

@MainActor
final class Inbox {
    let label: String
    private(set) var events: [(String, [String: Any])] = []
    init(_ label: String) { self.label = label }

    func record(_ event: String, _ payload: Any) {
        let dict = (payload as? [String: Any]) ?? [:]
        events.append((event, dict))
    }

    /// Wait until a predicate over recorded events for `event` is satisfied.
    func waitFor(_ event: String, timeout: TimeInterval = 6.0,
                 where predicate: @escaping ([String: Any]) -> Bool = { _ in true }) async -> [String: Any]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let match = events.last(where: { $0.0 == event && predicate($0.1) }) {
                return match.1
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    func count(_ event: String) -> Int { events.filter { $0.0 == event }.count }
}

// Helper: semantic fields for room broadcasts live under `.data`
func dataOf(_ envelope: [String: Any]) -> [String: Any] {
    return (envelope["data"] as? [String: Any]) ?? envelope
}

func numeric(_ v: Any?) -> Double? {
    if let d = v as? Double { return d }
    if let i = v as? Int { return Double(i) }
    if let n = v as? NSNumber { return n.doubleValue }
    if let s = v as? String { return Double(s) }
    return nil
}

// The worker's directed events carry `from` as an object {userId, identity}
// (challengeEvents.js inviteFrom()), not a flat string. Accept either shape.
func fromUserId(_ env: [String: Any]) -> String? {
    if let obj = env["from"] as? [String: Any] { return obj["userId"] as? String }
    if let s = env["from"] as? String { return s }
    return env["fromUserId"] as? String
}

// MARK: - Build clients

@MainActor
func makeClient(userId: String) throws -> OddSocketsClient {
    let config = try OddSocketsConfigBuilder()
        .apiKey(apiKey)
        .managerUrl(managerUrl)
        .userId(userId)
        .autoConnect(false)
        .build()
    return try OddSocketsClient(config: config)
}

// Broadcasts we care about on the room surface
let watchedBroadcasts = [
    "challenge_progress", "leaderboard_rank_change", "challenge_complete",
    "achievement_unlock", "achievement_progress",
    "challenge_invited", "challenge_reply_received", "challenge_invite_cancelled"
]

@MainActor
func run() async {
    let results = Results()
    log("=== OddSockets Swift SDK — Challenge two-client regression ===")
    log("manager: \(managerUrl)")
    log("challengeId: \(challengeId)  achievementId: \(achievementId)  room: \(room)")

    let alice: OddSocketsClient
    let bob: OddSocketsClient
    do {
        alice = try makeClient(userId: "alice_\(runId)")
        bob = try makeClient(userId: "bob_\(runId)")
    } catch {
        results.assert("build clients", false, "\(error)")
        finish(results); return
    }

    let aliceIn = Inbox("alice")
    let bobIn = Inbox("bob")

    // Register listeners BEFORE connect so nothing is missed.
    for ev in watchedBroadcasts {
        alice.on(ev) { payload in Task { @MainActor in aliceIn.record(ev, payload) } }
        bob.on(ev) { payload in Task { @MainActor in bobIn.record(ev, payload) } }
    }

    // Connect both
    do {
        try await alice.connect()
        try await bob.connect()
    } catch {
        results.assert("connect both clients", false, "\(error)")
        finish(results); return
    }
    results.assert("connect both clients", alice.isConnected && bob.isConnected)

    let aliceWorker = alice.workerInfo.workerId ?? "?"
    let bobWorker = bob.workerInfo.workerId ?? "?"
    results.note("alice workerId=\(aliceWorker)  bob workerId=\(bobWorker)")

    // Subscribe both to lobby
    do {
        let ac = try alice.channel(room)
        let bc = try bob.channel(room)
        try await ac.subscribe(handler: { _ in })
        try await bc.subscribe(handler: { _ in })
    } catch {
        results.assert("subscribe lobby", false, "\(error)")
        finish(results); return
    }
    // Give the room joins a moment to settle server-side.
    try? await Task.sleep(nanoseconds: 800_000_000)
    results.assert("subscribe lobby", true)

    // ---- 1. createChallenge (alice) => ack challenge_create_success
    do {
        let ack = try await alice.enhanced.createChallenge(
            challengeId: challengeId, metric: "score", ranked: true, channel: room)
        results.assert("createChallenge acked", true, "ack keys: \(ack.keys.sorted())")
    } catch {
        results.assert("createChallenge acked", false, "\(error)")
    }

    // ---- 2. reportProgress: alice=40, bob=55 => alice sees challenge_progress + leaderboard_rank_change
    let ev1 = "evt_\(runId)_a"
    let ev2 = "evt_\(runId)_b"
    alice.enhanced.reportProgress(challengeId: challengeId, value: 40, metric: "score", eventId: ev1, channel: room)
    try? await Task.sleep(nanoseconds: 400_000_000)
    bob.enhanced.reportProgress(challengeId: challengeId, value: 55, metric: "score", eventId: ev2, channel: room)

    // alice should see progress from bob's report + a rank change broadcast
    let progOnAlice = await aliceIn.waitFor("challenge_progress", timeout: 6.0)
    results.assert("alice sees challenge_progress", progOnAlice != nil,
                   progOnAlice.map { "data=\(dataOf($0))" } ?? "not received")

    let rankOnAlice = await aliceIn.waitFor("leaderboard_rank_change", timeout: 6.0)
    results.assert("alice sees leaderboard_rank_change", rankOnAlice != nil,
                   rankOnAlice.map { "data=\(dataOf($0))" } ?? "not received")

    // Ensure bob's 55 has actually been broadcast/persisted before querying
    // standings (alice's earlier waitFor matched her OWN echoed 40 and could
    // otherwise race ahead of bob's write on the other worker).
    _ = await aliceIn.waitFor("challenge_progress", timeout: 6.0) { env in
        numeric(dataOf(env)["value"]) == 55
    }
    try? await Task.sleep(nanoseconds: 400_000_000)

    // ---- 3. getStandings (alice) => bob@55 rank1, alice@40 rank2, alice yourRank=2
    do {
        let standings = try await alice.enhanced.getStandings(challengeId: challengeId, limit: 10)
        let rows = (standings["standings"] as? [[String: Any]]) ?? []
        let yourRank = numeric(standings["yourRank"])
        // Find rows by value
        let bobRow = rows.first { numeric($0["value"]) == 55 }
        let aliceRow = rows.first { numeric($0["value"]) == 40 }
        let bobRank = bobRow.flatMap { numeric($0["rank"]) }
        let aliceRank = aliceRow.flatMap { numeric($0["rank"]) }
        results.assert("standings bob@55 rank1", bobRank == 1, "bobRank=\(String(describing: bobRank)) rows=\(rows.count)")
        results.assert("standings alice@40 rank2", aliceRank == 2, "aliceRank=\(String(describing: aliceRank))")
        results.assert("standings alice yourRank=2", yourRank == 2, "yourRank=\(String(describing: yourRank))")
    } catch {
        results.assert("getStandings", false, "\(error)")
    }

    // ---- 4. complete: alice(tied)=>finalValue40 rank2, bob(conceded)=>finalValue55 rank1
    do {
        let aRes = try await alice.enhanced.completeChallenge(
            challengeId: challengeId, outcome: "tied", eventId: "\(ev1)_c")
        let outcome = aRes["outcome"] as? String
        let finalVal = numeric(aRes["finalValue"])
        let rank = numeric(aRes["rank"])
        results.assert("alice complete tied finalValue=40 rank=2",
                       outcome == "tied" && finalVal == 40 && rank == 2,
                       "outcome=\(String(describing: outcome)) finalValue=\(String(describing: finalVal)) rank=\(String(describing: rank))")
    } catch {
        results.assert("alice complete tied", false, "\(error)")
    }
    do {
        let bRes = try await bob.enhanced.completeChallenge(
            challengeId: challengeId, outcome: "conceded", eventId: "\(ev2)_c")
        let outcome = bRes["outcome"] as? String
        let finalVal = numeric(bRes["finalValue"])
        let rank = numeric(bRes["rank"])
        results.assert("bob complete conceded finalValue=55 rank=1",
                       outcome == "conceded" && finalVal == 55 && rank == 1,
                       "outcome=\(String(describing: outcome)) finalValue=\(String(describing: finalVal)) rank=\(String(describing: rank))")
    } catch {
        results.assert("bob complete conceded", false, "\(error)")
    }

    // ---- 5. alice unlock(50) => bob sees achievement_progress in_progress, no banner
    alice.enhanced.unlockAchievement(achievementId: achievementId, name: "Swift Grinder",
                                     percentComplete: 50, channel: room)
    let progAch = await bobIn.waitFor("achievement_progress", timeout: 6.0) { env in
        let d = dataOf(env)
        return (d["achievementId"] as? String) == achievementId || (env["achievementId"] as? String) == achievementId
    }
    if let progAch = progAch {
        let d = dataOf(progAch)
        let status = (d["status"] as? String) ?? (progAch["status"] as? String)
        results.assert("bob sees achievement_progress in_progress", status == "in_progress",
                       "status=\(String(describing: status))")
    } else {
        results.assert("bob sees achievement_progress in_progress", false, "not received")
    }
    // No unlock banner yet
    results.assert("no achievement_unlock banner at 50%", bobIn.count("achievement_unlock") == 0,
                   "unlock count=\(bobIn.count("achievement_unlock"))")

    // ---- 6. alice unlock(100) => bob sees achievement_unlock unlocked
    alice.enhanced.unlockAchievement(achievementId: achievementId, name: "Swift Grinder",
                                     percentComplete: 100, channel: room)
    let unlockAch = await bobIn.waitFor("achievement_unlock", timeout: 6.0) { env in
        let d = dataOf(env)
        return (d["achievementId"] as? String) == achievementId || (env["achievementId"] as? String) == achievementId
    }
    if let unlockAch = unlockAch {
        let d = dataOf(unlockAch)
        let status = (d["status"] as? String) ?? (unlockAch["status"] as? String)
        results.assert("bob sees achievement_unlock unlocked", status == nil || status == "unlocked",
                       "status=\(String(describing: status))")
    } else {
        results.assert("bob sees achievement_unlock unlocked", false, "not received")
    }

    // ---- getAchievements (alice) => achievementId 100/unlocked
    do {
        let state = try await alice.enhanced.getAchievements(achievementId: achievementId)
        let list = (state["achievements"] as? [[String: Any]]) ?? []
        let row = list.first { ($0["achievementId"] as? String) == achievementId }
        let pct = row.flatMap { numeric($0["percentComplete"]) }
        let status = row?["status"] as? String
        results.assert("getAchievements 100/unlocked", pct == 100 && status == "unlocked",
                       "pct=\(String(describing: pct)) status=\(String(describing: status)) rows=\(list.count)")
    } catch {
        results.assert("getAchievements", false, "\(error)")
    }

    // ---- 7. alice invite bob => bob sees challenge_invited (FLAT: from/payload top level); alice not own
    var inviteId: String? = nil
    do {
        let ack = try await alice.enhanced.sendChallengeInvite(
            toUserId: "bob_\(runId)", type: "match",
            payload: ["mode": "duel", "run": runId], ttl: 300, channel: room)
        inviteId = ack["inviteId"] as? String
        let toUser = ack["toUserId"] as? String
        let status = ack["status"] as? String
        results.assert("invite acked pending", inviteId != nil && status == "pending",
                       "inviteId=\(inviteId ?? "nil") to=\(String(describing: toUser)) status=\(String(describing: status))")
    } catch {
        results.assert("invite acked pending", false, "\(error)")
    }

    let invitedOnBob = await bobIn.waitFor("challenge_invited", timeout: 6.0) { env in
        // FLAT shape
        (env["inviteId"] as? String) == inviteId || inviteId == nil
    }
    if let invitedOnBob = invitedOnBob {
        // FLAT: from (object {userId,identity}) / payload at top level
        let from = fromUserId(invitedOnBob)
        let payload = (invitedOnBob["payload"] as? [String: Any]) ?? [:]
        results.assert("bob sees challenge_invited from alice", from == "alice_\(runId)",
                       "from=\(String(describing: from)) payload=\(payload)")
    } else {
        results.assert("bob sees challenge_invited from alice", false, "not received")
    }
    // alice should NOT receive her own invite
    results.assert("alice does not see own invite", aliceIn.count("challenge_invited") == 0,
                   "alice invited count=\(aliceIn.count("challenge_invited"))")

    // ---- 8. bob getChallengeInvites lists it
    do {
        let res = try await bob.enhanced.getChallengeInvites()
        let invites = (res["invites"] as? [[String: Any]]) ?? []
        let found = invites.contains { ($0["inviteId"] as? String) == inviteId }
        results.assert("bob getChallengeInvites lists invite", found,
                       "count=\(invites.count) inviteId=\(inviteId ?? "nil")")
    } catch {
        results.assert("bob getChallengeInvites", false, "\(error)")
    }

    // ---- 9. bob reply(accept) => alice sees challenge_reply_received (FLAT)
    if let inviteId = inviteId {
        do {
            _ = try await bob.enhanced.replyChallengeInvite(inviteId: inviteId, accept: true)
            results.assert("bob reply accept acked", true)
        } catch {
            results.assert("bob reply accept acked", false, "\(error)")
        }
        let replyOnAlice = await aliceIn.waitFor("challenge_reply_received", timeout: 6.0) { env in
            (env["inviteId"] as? String) == inviteId
        }
        if let replyOnAlice = replyOnAlice {
            let accept = (replyOnAlice["accept"] as? Bool) ?? ((replyOnAlice["accepted"] as? Bool))
            let from = fromUserId(replyOnAlice)
            results.assert("alice sees challenge_reply_received accepted", accept == true,
                           "accept=\(String(describing: accept)) from=\(String(describing: from))")
        } else {
            results.assert("alice sees challenge_reply_received accepted", false, "not received")
        }
    } else {
        results.assert("bob reply accept acked", false, "no inviteId")
        results.assert("alice sees challenge_reply_received accepted", false, "no inviteId")
    }

    // ---- 10. fresh invite + cancel => bob sees challenge_invite_cancelled (FLAT)
    var invite2: String? = nil
    do {
        let ack = try await alice.enhanced.sendChallengeInvite(
            toUserId: "bob_\(runId)", type: "match",
            payload: ["mode": "cancel-me", "run": runId], ttl: 300, channel: room)
        invite2 = ack["inviteId"] as? String
        results.assert("fresh invite acked", invite2 != nil, "inviteId=\(invite2 ?? "nil")")
    } catch {
        results.assert("fresh invite acked", false, "\(error)")
    }
    // Wait for bob to see it delivered before cancelling
    _ = await bobIn.waitFor("challenge_invited", timeout: 6.0) { env in
        (env["inviteId"] as? String) == invite2
    }
    if let invite2 = invite2 {
        do {
            _ = try await alice.enhanced.cancelChallengeInvite(inviteId: invite2)
            results.assert("cancel invite acked", true)
        } catch {
            results.assert("cancel invite acked", false, "\(error)")
        }
        let cancelOnBob = await bobIn.waitFor("challenge_invite_cancelled", timeout: 6.0) { env in
            (env["inviteId"] as? String) == invite2
        }
        results.assert("bob sees challenge_invite_cancelled", cancelOnBob != nil,
                       cancelOnBob.map { "inviteId=\($0["inviteId"] ?? "?")" } ?? "not received")
    } else {
        results.assert("cancel invite acked", false, "no inviteId")
        results.assert("bob sees challenge_invite_cancelled", false, "no inviteId")
    }

    // Cleanup
    await alice.disconnect()
    await bob.disconnect()

    finish(results)
}

@MainActor
func finish(_ results: Results) {
    log("\n--- Per-assertion results ---")
    for l in results.lines { log(l) }
    log("\n--- Summary ---")
    log("PASS=\(results.pass)  FAIL=\(results.fail)")
    log(results.fail == 0 ? "RESULT: PASS" : "RESULT: FAIL")
    fflush(stdout)
    exit(results.fail == 0 ? 0 : 1)
}

// Entry. Do NOT block the main thread with a semaphore: the SDK is @MainActor
// and its continuations resume on the main executor, so blocking here starves
// the actor and deadlocks. Instead schedule work on the main queue and let
// dispatchMain() drive the run loop; each path calls exit() when finished.
Task { @MainActor in
    await run()
}
// Wall-clock watchdog on a background queue.
DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
    FileHandle.standardError.write(Data("\nWATCHDOG: exceeded 120s wall clock — aborting\n".utf8))
    exit(3)
}
dispatchMain()
