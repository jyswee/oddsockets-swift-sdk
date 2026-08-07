import XCTest
@testable import OddSockets

final class OddSocketsTests: XCTestCase {
    func testConfigValidationRejectsEmptyApiKey() {
        let config = OddSocketsConfig(apiKey: "")
        XCTAssertThrowsError(try config.validate())
    }

    func testConfigValidationAcceptsApiKey() {
        let config = OddSocketsConfig(apiKey: "ak_test_key")
        XCTAssertNoThrow(try config.validate())
    }

    func testConfiguredManagerUrlIsUsedVerbatim() throws {
        let discovery = try ManagerDiscovery(configuredUrl: "https://example.invalid/custom")
        XCTAssertEqual(discovery.discoverManagerUrl(), "https://example.invalid/custom")
        XCTAssertNotEqual(discovery.discoverManagerUrl(), ManagerDiscovery.defaultManagerUrl)
    }

    func testTrailingSlashesAreStripped() throws {
        let discovery = try ManagerDiscovery(configuredUrl: "https://example.invalid/custom//")
        XCTAssertEqual(discovery.discoverManagerUrl(), "https://example.invalid/custom")
    }

    func testInvalidManagerUrlIsRejected() {
        XCTAssertThrowsError(try ManagerDiscovery(configuredUrl: "not-a-url")) { error in
            guard case OddSocketsError.invalidConfiguration(let message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }
            XCTAssertEqual(message, "Invalid managerUrl: not-a-url")
        }
    }

    func testNonHttpManagerUrlIsRejected() {
        XCTAssertThrowsError(try ManagerDiscovery(configuredUrl: "ftp://example.invalid"))
        XCTAssertThrowsError(try ManagerDiscovery(configuredUrl: "/api/cluster"))
    }

    func testConfigRejectsInvalidManagerUrlInsteadOfDefaultingToProduction() {
        let config = OddSocketsConfig(apiKey: "ak_test_key", managerUrl: "not-a-url")
        XCTAssertThrowsError(try config.validate())
    }

    func testConfiguredManagerUrlSurvivesTheBuilder() throws {
        let config = try OddSocketsConfigBuilder
            .with(apiKey: "ak_test_key")
            .managerUrl("https://example.invalid/custom")
            .build()
        XCTAssertEqual(config.managerUrl, "https://example.invalid/custom")
    }

    func testDefaultAppliesOnlyWhenNothingIsConfigured() {
        // The environment variable is process-global, so only assert the
        // built-in default when the ambient environment has not set it.
        let environmentValue = ProcessInfo.processInfo
            .environment[ManagerDiscovery.environmentVariableName]
        guard environmentValue == nil else { return }

        let config = OddSocketsConfig(apiKey: "ak_test_key")
        XCTAssertEqual(config.managerUrl, ManagerDiscovery.defaultManagerUrl)
    }
}
