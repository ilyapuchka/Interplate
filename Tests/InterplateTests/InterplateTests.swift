import XCTest
import Interplate

final class InterplateTests: XCTestCase {
    func testHelloWorld() {
        let t: Template = "Hello world!"
        XCTAssertEqual(t.render(), "Hello world!")
    }

    func testDefault() {
        let name: String? = nil
        let t: Template = "Hello \(name, default: "world")!"
        XCTAssertEqual(t.render(), "Hello world!")
    }

    func testLoop() {
        let names = ["Foo", "Bar", "FooBar"]
        let t: Template = """
        Hello \(for: names, do: { name, loop in
        "\(name)\(loop.end ? "" : loop.index + 1 == loop.length - 1 ? " and " : ", ")"
        })!
        """
        XCTAssertEqual(t.render(), "Hello Foo, Bar and FooBar!")
    }

    func testIndent() {
        let t: Template = "\(indent: 2, indentFirstLine: true, "Hello world!")"
        XCTAssertEqual(t.render(), "  Hello world!")
    }

    func testTrim() {
        let t: Template = "  \(_trim_: .w)  Hello world!  \(_trim: .w)"
        XCTAssertEqual(t.render(), "Hello world!")
    }

    func testInclude() {
        let t1: Template = "Hello"
        let t2: Template = "\(t1) world!"
        XCTAssertEqual(t2.render(), "Hello world!")
    }

    func testExtension() {
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "y-MM-dd"
        let date = df.string(from: now)

        let t: Template = "\(h1: "Today is \(date: now, format: "y-MM-dd")")"
        XCTAssertEqual(t.render(), "<h1>Today is \(date)</h1>")
    }

}

extension Template.StringInterpolation {
    static let dateFormatter = DateFormatter()
    func appendInterpolation(date: Date = Date(), format: String) {
        Template.StringInterpolation.dateFormatter.dateFormat = format
        appendLiteral(Template.StringInterpolation.dateFormatter.string(from: date))
    }

    func appendInterpolation(h1 body: Template) {
        appendInterpolation("<h1>\(body)</h1>" as Template)
    }
}
