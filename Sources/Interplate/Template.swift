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
        private var trim: (characters: CharacterSet, direction: TrimDirection)? = nil

        required public init(literalCapacity: Int, interpolationCount: Int) {
            self.parts = []
            self.parts.reserveCapacity(2*interpolationCount+1)
        }

        public func appendLiteral(_ literal: String) {
            if let trim = trim {
                if trim.direction.contains(.before), parts.count > 0 {
                    let lastPart = parts.removeLast()
                    self.parts.append(
                        String(lastPart.reversed().drop {
                            CharacterSet(charactersIn: String($0)).isSubset(of: trim.characters)
                            }.reversed()
                        )
                    )
                }
                if trim.direction.contains(.after) {
                    self.parts.append(
                        String(literal.drop {
                            CharacterSet(charactersIn: String($0)).isSubset(of: trim.characters)
                        })
                    )
                } else {
                    self.parts.append(literal)
                }
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

        public func appendInterpolation(indent: Int, with: String = " ") {
            appendInterpolation(indent: indent, with: with, indentFirstLine: true, "")
        }

        public func appendInterpolation(keepEmptyLines: Bool, _ body: @autoclosure () -> Template) {
            appendInterpolation(indent: 0, keepEmptyLines: keepEmptyLines, body())
        }

        public func appendInterpolation(indent: Int,
                                        with: String = " ",
                                        indentFirstLine: Bool = false,
                                        keepEmptyLines: Bool = false,
                                        _ body: @autoclosure () -> Template) {
            let indented = body().render().indent(
                indent,
                with: with,
                indentFirstLine: indentFirstLine,
                keepEmptyLines: keepEmptyLines
            )
            appendLiteral(indented)
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

        public struct TrimDirection: OptionSet {
            public let rawValue: Int
            public init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public static let before = TrimDirection(rawValue: 1 << 0)
            public static let after = TrimDirection(rawValue: 1 << 1)
        }

        public func appendInterpolation(trim characters: CharacterSet, _ direction: TrimDirection = .after) {
            trim = (characters, direction)
        }
        public func appendInterpolation(_trim characters: CharacterSet) {
            trim = (characters, .before)
        }
        public func appendInterpolation(trim_ characters: CharacterSet) {
            trim = (characters, .after)
        }
        public func appendInterpolation(_trim_ characters: CharacterSet) {
            trim = (characters, [.before, .after])
        }
    }
}


extension String {
    private static let newlinesCharacterSet = CharacterSet(charactersIn: "\u{000A}\u{000D}")

    func lines() -> [String] {
        return components(separatedBy: String.newlinesCharacterSet)
    }

    func indent(_ indent: Int = 4, with: String = " ", indentFirstLine: Bool = false, keepEmptyLines: Bool = false) -> String {
        var n = 0
        var indented: [String] = []
        let indentation = Array(repeating: with, count: indent).joined()

        lines().forEach { line in
            if keepEmptyLines || line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                indented.append((indentFirstLine == false && n == 0 ? "" : indentation) + line)
            }
            n += 1
        }
        return indented.joined(separator: "\n")
    }
}

public extension CharacterSet {
    static let w = CharacterSet.whitespaces
    static let n = CharacterSet.newlines
    static let wn = CharacterSet.whitespacesAndNewlines
}
