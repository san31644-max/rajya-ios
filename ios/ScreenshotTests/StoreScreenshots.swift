import XCTest

// Exercise the released native screens and public API. No sample accounts,
// invented content, mock screens, or credentials are used in these captures.
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        XCTAssertTrue(app.staticTexts["K EDUCATION · රාජ්‍ය"].waitForExistence(timeout: 45))
        Thread.sleep(forTimeInterval: 2)
    }
    override func tearDownWithError() throws { app.terminate() }
    private func tab(_ label: String) {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 20), "Missing tab: \(label)")
        button.tap()
    }
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 2)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
    func test01Home() {
        capture("01-home")
    }
    func test02OfflineLibrary() {
        tab("පුස්තකාලය")
        XCTAssertTrue(app.staticTexts["ආයතන සංග්‍රහය — I වැනි කාණ්ඩය"].firstMatch.waitForExistence(timeout: 20))
        capture("02-offline-library")
    }
    func test03PDFReader() {
        tab("පුස්තකාලය")
        let book = app.staticTexts["ආයතන සංග්‍රහය — I වැනි කාණ්ඩය"].firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 20)); book.tap()
        let jump = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "පිටුව ")).firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 30)); jump.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap()
        field.typeText(XCUIKeyboardKey.delete.rawValue + "42")
        app.alerts.buttons["Go"].tap()
        XCTAssertTrue(app.buttons["පිටුව 42 / 531"].waitForExistence(timeout: 20))
        capture("03-native-pdf-reader")
    }
    func test04Learning() {
        tab("ඉගෙනුම")
        XCTAssertTrue(app.staticTexts["රාජ්‍ය සේවයේ පදනම"].firstMatch.waitForExistence(timeout: 60))
        capture("04-learning-paths")
    }
    func test05Lesson() {
        tab("ඉගෙනුම")
        let course = app.staticTexts["රාජ්‍ය සේවයේ පදනම"].firstMatch
        XCTAssertTrue(course.waitForExistence(timeout: 60)); course.tap()
        XCTAssertTrue(app.navigationBars["රාජ්‍ය සේවයේ පදනම"].waitForExistence(timeout: 60))
        capture("05-source-based-lessons")
    }
    func test06Practice() {
        tab("ඉගෙනුම")
        let practice = app.buttons["ප්‍රශ්න පුහුණුව / Practice"]
        XCTAssertTrue(practice.waitForExistence(timeout: 20)); practice.tap()
        let counter = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^1 / [0-9]+$")).firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 60))
        capture("06-practice-questions")
    }
    func test07Guides() {
        tab("ඉගෙනුම")
        let guides = app.buttons["කාර්ය පටිපාටි / Procedure guides"]
        XCTAssertTrue(guides.waitForExistence(timeout: 20)); guides.tap()
        XCTAssertTrue(app.staticTexts["Draft / unreviewed · කෙටුම්පත"].firstMatch.waitForExistence(timeout: 60))
        capture("07-procedure-guides")
    }
}
