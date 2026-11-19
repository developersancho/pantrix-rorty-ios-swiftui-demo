// Temporary: here only to see how the build reports warnings. Not part of the repository.
import UIKit
import XCTest

final class TemporaryWarningsProbe: XCTestCase {
    func testWarnings() {
        let unused = 1
        var neverChanged = "İstanbul 😀"; let afterEmoji = 2
        let window = UIApplication.shared.keyWindow
        XCTAssertNil(window)
        XCTAssertEqual(neverChanged.count, 10)
    }
}
