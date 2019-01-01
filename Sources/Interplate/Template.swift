import Foundation

open class Renderer {
    public init() {}

    open var template: Template {
        return ""
    }

    public func render() -> String {
        return template.render()
    }
}

public class Template: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public enum Error: Swift.Error {
        case templateNotFound(String)
    }

    public let sourcePath: String
    let parts: [String]

    public required init(stringLiteral value: String) {
        self.parts = [value]
        self.sourcePath = ""
    }

    public required init(stringInterpolation: Template.StringInterpolation) {
        self.parts = stringInterpolation.parts
        self.sourcePath = ""
    }

    public init?(sourcePath: String) {
        guard let data = FileManager.default.contents(atPath: sourcePath),
            let content = String(data: data, encoding: .utf8) else {
                return nil
        }
        self.sourcePath = sourcePath
        self.parts = [content]
    }

    public func render() -> String {
        return parts.joined()
    }

    public class StringInterpolation: StringInterpolationProtocol {
        private(set) var parts: [String]
        private var trim: CharacterSet? = nil

        required public init(literalCapacity: Int, interpolationCount: Int) {
            self.parts = []
            self.parts.reserveCapacity(2*interpolationCount+1)
        }

        public func appendLiteral(_ literal: String) {
            if let trim = trim {
                self.parts.append(
                    String(literal.drop {
                        CharacterSet(charactersIn: String($0)).isSubset(of: trim)
                    })
                )
                self.trim = nil
            } else {
                self.parts.append(literal)
            }
        }

        public func appendInterpolation(_ literal: String) {
            appendLiteral(literal)
        }

        public func appendInterpolation(_ literal: String?, `default`: String = "") {
            appendLiteral(literal ?? `default`)
        }

        public func appendInterpolation(_ template: @autoclosure () -> Template) {
            template().parts.forEach(appendLiteral)
        }

        public func appendInterpolation(indent: Int = 4,
                                        with: String = " ",
                                        indentFirstLine: Bool = false,
                                        _ body: @autoclosure () -> Template) {
            let content = body().render()
            var n = 0
            var indented: [String] = []
            let indentation = Array(repeating: with, count: indent).joined()
            content.enumerateLines { (line, _) in
                indented.append((indentFirstLine == false && n == 0 ? "" : indentation) + line)
                n += 1
            }
            appendLiteral(indented.joined(separator: "\n"))
        }

        public class LoopContext {
            public let length: Int
            public private(set) var index: Int = -1
            public var start: Bool {
                return index == 0
            }
            public var end: Bool {
                return index == length - 1
            }

            init(length: Int) {
                self.length = length
            }

            func next() -> LoopContext {
                index += 1
                return self
            }
        }

        public func appendInterpolation<T>(for collection: [T],
                                           where predicate: (T) -> Bool = { _ in true },
                                           do body: (T, LoopContext) -> Template,
                                           empty: @autoclosure () -> Template = "") {
            let c = collection.filter(predicate)
            let loop = LoopContext(length: c.count)
            if c.count > 0 {
                c.forEach { appendInterpolation(body($0, loop.next())) }
            } else {
                appendInterpolation(empty())
            }
        }

        public func appendInterpolation(include path: String) throws {
            guard let template = Template(sourcePath: path) else {
                throw Error.templateNotFound(path)
            }
            appendInterpolation(template)
        }

        public func appendInterpolation(include path: String, notFound: @autoclosure () -> Template) {
            appendInterpolation(Template(sourcePath: path) ?? notFound())
        }

        public func appendInterpolation(trim characters: CharacterSet) {
            trim = characters
        }
    }
}
