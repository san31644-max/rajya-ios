import XCTest
@testable import Rajya

final class CoreTests: XCTestCase {
    func testPDOStringsAndNumbersDecodeConsistently() throws {
        let data = Data(#"{"id":"12","count":12,"active":true,"missing":null}"#.utf8)
        let value = try JSONDecoder().decode(Value.self, from: data)
        XCTAssertEqual(value["id"].int, value["count"].int)
        XCTAssertTrue(value["active"].flag)
        XCTAssertEqual(value["missing"], .null)
        XCTAssertEqual(value["absent"].text, "")
    }
    func testDatabaseJSONColumnsAndAnswerIndices() throws {
        let choices = Value.string(#"["first","second","third","fourth"]"#)
        XCTAssertEqual(choices.list.count, 4)
        let answers = Value.object(["12": .id(0), "18": .id(3)])
        let encoded = try JSONEncoder().encode(answers)
        let decoded = try JSONDecoder().decode(Value.self, from: encoded)
        XCTAssertEqual(decoded["12"].int, 0)
        XCTAssertEqual(decoded["18"].int, 3)
        XCTAssertEqual(decoded["99"], .null)
    }
    func testBundledReferencesHaveOriginalPageCounts() {
        let books = ReferenceBook.all
        XCTAssertEqual(books.count, 3)
        XCTAssertEqual(books.reduce(0) { $0 + $1.pages }, 977)
        XCTAssertEqual(Set(books.map(\.id)).count, 3)
        for book in books { XCTAssertNotNil(book.url); XCTAssertEqual(book.sha256.count, 64) }
    }
}
