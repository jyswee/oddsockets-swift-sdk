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
}
