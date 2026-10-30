import XCTest
@testable import UsefulTravelClock

final class RequestAndInboxTests: XCTestCase {
    @MainActor
    func testOlderResponseCannotReplaceNewerSelection() async {
        let scope = TripRequestScope()
        var older: CheckedContinuation<Void, Never>?
        var newer: CheckedContinuation<Void, Never>?
        var displayed = ""
        let first = scope.run { revision in
            await withCheckedContinuation { older = $0 }
            if scope.accepts(revision) { displayed = "old city" }
        }
        for _ in 0..<1000 { if older != nil { break }; await Task.yield() }
        guard let older else { first.cancel(); XCTFail("Older request did not start"); return }
        let second = scope.run { revision in
            await withCheckedContinuation { newer = $0 }
            if scope.accepts(revision) { displayed = "new city" }
        }
        for _ in 0..<1000 { if newer != nil { break }; await Task.yield() }
        guard let newer else {
            older.resume(); await first.value; second.cancel()
            XCTFail("Newer request did not start"); return
        }
        newer.resume(); await second.value
        XCTAssertEqual(displayed, "new city")
        // Simulate a service that returns after cancellation was requested.
        older.resume(); await first.value
        XCTAssertEqual(displayed, "new city")
    }

    @MainActor
    func testLeavingScreenRejectsItsPendingResponse() async {
        let scope = TripRequestScope()
        var completion: CheckedContinuation<Void, Never>?
        var updatedHiddenScreen = false
        let task = scope.run { revision in
            await withCheckedContinuation { completion = $0 }
            updatedHiddenScreen = scope.accepts(revision)
        }
        for _ in 0..<1000 { if completion != nil { break }; await Task.yield() }
        guard let completion else { task.cancel(); XCTFail("Request did not start"); return }
        scope.cancel()
        completion.resume(); await task.value
        XCTAssertFalse(updatedHiddenScreen)
    }

    @MainActor
    func testIncomingFilesKeepTheirOrderAndIgnoreInvalidURLs() {
        let inbox = TripDocumentInbox()
        defer { inbox.clear() }
        let first = URL(fileURLWithPath: "/tmp/first-ticket.pdf")
        let second = URL(fileURLWithPath: "/tmp/second-ticket.pdf")
        let third = URL(fileURLWithPath: "/tmp/third-ticket.pdf")
        inbox.receive(first)
        inbox.receive(second)
        inbox.receive(second) // A repeated callback must not queue a duplicate.
        inbox.receive(URL(string: "https://example.com/")!)
        inbox.receive(third)
        XCTAssertEqual(inbox.url, first)
        inbox.finishCurrent(); XCTAssertEqual(inbox.url, second)
        inbox.finishCurrent(); XCTAssertEqual(inbox.url, third)
        inbox.finishCurrent(); XCTAssertNil(inbox.url)
        inbox.receive(first); inbox.receive(second); inbox.clear()
        inbox.finishCurrent(); XCTAssertNil(inbox.url)
    }
}
