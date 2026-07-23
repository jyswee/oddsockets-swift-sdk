// OddSockets Swift SDK - two-client honest regression demo
//
// Everything here runs through the REAL OddSockets platform: Manager -> Worker
// discovery over HTTP, a genuine Socket.IO connection per client, and live
// broadcast fan-out between two SEPARATE connections. No mocks, no local echo.
//
// Scenario 1 - core pub/sub:
//   alice subscribes, bob publishes a nonce-tagged message on a second
//   connection, alice receives it via her subscription handler.
//
// Scenario 2 - enhanced (Slack-like) events:
//   both clients subscribe to an enhanced channel. alice registers public
//   on("user_typing") + on("reaction_added") listeners. bob fires
//   enhanced.startTyping + enhanced.addReaction. alice receives both
//   broadcasts across the wire.
//
// Run:
//   export ODDSOCKETS_API_KEY="ak_..."   # get a free key: see README
//   swift run
//
// Exit codes: 0 all green, 1 missing key / setup, 2 a scenario timed out.

import Foundation
import OddSockets

/// Mutable, reference-typed signal flags shared with MainActor callbacks.
final class Flags {
    var coreReceived = false
    var typingSeen = false
    var reactionSeen = false
}

@main
struct OddSocketsDemo {
    static func main() async {
        setbuf(stdout, nil)
        let code = await Runner.run()
        exit(code)
    }
}

@MainActor
enum Runner {
    static func run() async -> Int32 {
        guard let apiKey = ProcessInfo.processInfo.environment["ODDSOCKETS_API_KEY"],
              !apiKey.isEmpty else {
            FileHandle.standardError.write(Data(
                "Missing ODDSOCKETS_API_KEY. Get a free key (see README), then:\n  export ODDSOCKETS_API_KEY=\"ak_...\"\n".utf8))
            return 1
        }

        let nonce = String(UInt64.random(in: 0..<UInt64.max), radix: 16)
        let flags = Flags()

        do {
            let alice = try await connect(apiKey: apiKey, userId: "alice")
            let bob = try await connect(apiKey: apiKey, userId: "bob")
            print("[connect] alice -> \(alice.workerInfo.workerId ?? "?"), bob -> \(bob.workerInfo.workerId ?? "?")")

            let core = try await scenarioCore(alice: alice, bob: bob, nonce: nonce, flags: flags)
            if !core { return 2 }

            let enhanced = try await scenarioEnhanced(alice: alice, bob: bob, nonce: nonce, flags: flags)
            if !enhanced { return 2 }

            await alice.disconnect()
            await bob.disconnect()

            print("\nOK - all scenarios verified live through the OddSockets platform")
            return 0
        } catch {
            FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
            return 1
        }
    }

    static func connect(apiKey: String, userId: String) async throws -> OddSocketsClient {
        let config = try OddSocketsConfigBuilder()
            .apiKey(apiKey)
            .userId(userId)
            .autoConnect(false)
            .build()
        let client = try OddSocketsClient(config: config)
        try await client.connect()
        return client
    }

    /// Scenario 1: bob publishes, alice (separate connection) receives.
    static func scenarioCore(alice: OddSocketsClient, bob: OddSocketsClient, nonce: String, flags: Flags) async throws -> Bool {
        let channelName = "demo-core-\(nonce)"
        // Marker lives only inside the message payload, never in the channel name,
        // so a match proves the real payload crossed the wire (not an echo of the
        // channel it arrived on).
        let marker = "marker=\(nonce)"
        print("\n=== Scenario 1: core pub/sub on \(channelName) ===")

        let aliceCh = try alice.channel(channelName)
        try await aliceCh.subscribe(handler: { (message: Message) in
            let rendered = String(describing: message.data)
            print("[alice recv] \(rendered)")
            if rendered.contains(marker) {
                flags.coreReceived = true
            }
        })
        print("[alice] subscribed")

        let bobCh = try bob.channel(channelName)
        try await bobCh.subscribe(handler: { (_: Message) in })
        print("[bob] subscribed")

        try await Task.sleep(nanoseconds: 500_000_000)

        let payload = AnyCodable([
            "text": "hello from bob \(marker)",
            "username": "bob",
            "messageType": "demo"
        ])
        let result = try await bobCh.publish(payload)
        print("[bob] published messageId=\(result.messageId)")

        let ok = await waitFor({ flags.coreReceived }, seconds: 15)
        if ok {
            print("[PASS] alice received bob's message across separate connections")
            await aliceCh.unsubscribe()
            await bobCh.unsubscribe()
            return true
        }
        FileHandle.standardError.write(Data("[FAIL] alice never received bob's message within 15s\n".utf8))
        return false
    }

    /// Scenario 2: bob fires enhanced typing + reaction, alice receives both
    /// broadcasts on her public on() surface.
    static func scenarioEnhanced(alice: OddSocketsClient, bob: OddSocketsClient, nonce: String, flags: Flags) async throws -> Bool {
        let channelName = "demo-enh-\(nonce)"
        print("\n=== Scenario 2: enhanced events on \(channelName) ===")

        let aliceCh = try alice.channel(channelName)
        try await aliceCh.subscribe(handler: { (_: Message) in })
        let bobCh = try bob.channel(channelName)
        try await bobCh.subscribe(handler: { (_: Message) in })
        print("[alice/bob] subscribed to enhanced channel")

        alice.on("user_typing") { payload in
            print("[alice on user_typing] \(payload)")
            flags.typingSeen = true
        }
        alice.on("reaction_added") { payload in
            print("[alice on reaction_added] \(payload)")
            flags.reactionSeen = true
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        let anchor = try await bobCh.publish(AnyCodable([
            "text": "enhanced anchor nonce=\(nonce)",
            "username": "bob",
            "messageType": "demo"
        ]))
        print("[bob] published anchor messageId=\(anchor.messageId)")

        bob.enhanced.startTyping(userId: "bob", channel: channelName)
        print("[bob] enhanced.startTyping fired")

        bob.enhanced.addReaction(
            messageId: anchor.messageId,
            channel: channelName,
            emoji: ":thumbsup:",
            userId: "bob",
            userName: "Bob"
        )
        print("[bob] enhanced.addReaction fired")

        let ok = await waitFor({ flags.typingSeen && flags.reactionSeen }, seconds: 15)
        await aliceCh.unsubscribe()
        await bobCh.unsubscribe()

        if ok {
            print("[PASS] alice received user_typing AND reaction_added from bob")
            return true
        }
        FileHandle.standardError.write(Data(
            "[FAIL] enhanced broadcasts missing (typing=\(flags.typingSeen), reaction=\(flags.reactionSeen))\n".utf8))
        return false
    }

    /// Polls a predicate on the main actor until true or the deadline passes.
    static func waitFor(_ predicate: () -> Bool, seconds: Int) async -> Bool {
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        while Date() < deadline {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return predicate()
    }
}
