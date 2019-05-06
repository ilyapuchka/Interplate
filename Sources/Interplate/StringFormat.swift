import Foundation
import CommonParsers
import Prelude

public final class StringTemplate: TemplateType {
    public let template: Template
    public let args: [CVarArg]

    init(template: Template, args: [CVarArg]) {
        self.template = template
        self.args = args
    }

    public static let empty: StringTemplate = StringTemplate(template: .empty, args: [])

    public static func <> (lhs: StringTemplate, rhs: StringTemplate) -> StringTemplate {
        return StringTemplate(template: lhs.template <> rhs.template, args: lhs.args <> rhs.args)
    }

    public var isEmpty: Bool {
        return template.isEmpty
    }

    public func render() -> String {
        return template.render()
    }
}

public struct StringFormat<A>: FormatType {
    public let parser: Parser<StringTemplate, A>
    public let format: Format<A>

    public init(_ parser: Parser<StringTemplate, A>) {
        self.parser = parser
        self.format = Format<A>(Parser(parse: { (template) -> (rest: Template, match: A)? in
            guard let match = try parser.parse(StringTemplate(template: template, args: [])) else { return nil }
            return (rest: match.rest.template, match: match.match)
        }, print: { (a) -> Template? in
            try parser.print(a)?.template
        }, template: { (a) -> Template? in
            try parser.template(a)?.template
        }))
    }

    public func match(_ template: StringTemplate) throws -> A? {
        return try (self <% StringFormat.end).parser.parse(template)?.match
    }

    public func render(_ a: A) throws -> String? {
        return try self.print(a).flatMap { $0.render() }
    }

    public func template(_ a: A) throws -> StringTemplate? {
        return try self.print(a)
    }

    public func localized(_ a: A, table: String? = nil, bundle: Bundle = .main, value: String? = nil) throws -> String? {
        guard let template = try parser.print(a) else { return nil }
        return String(
            format: bundle.localizedString(forKey: template.render(), value: value, table: table),
            arguments: template.args
        )
    }

}

#if swift(>=5.0)
extension StringFormat: ExpressibleByStringInterpolation {

    public init(stringLiteral value: String) {
        self.init(slit(String(value)).map(.any))
    }

    public init(stringInterpolation: StringInterpolation) {
        if stringInterpolation.parsers.isEmpty {
            self.init(.empty)
        } else {
            let parser = reduce(parsers: stringInterpolation.parsers)
            self.init(parser.map(.any))
        }
    }

    public class StringInterpolation: StringInterpolationProtocol {
        private(set) var parsers: [(Parser<StringTemplate, Any>, Any.Type)] = []

        public required init(literalCapacity: Int, interpolationCount: Int) {
        }

        public func appendParser<A>(_ parser: Parser<StringTemplate, A>) {
            parsers.append((parser.map(.any), A.self))
        }

        public func appendLiteral(_ literal: String) {
            appendParser(slit(literal))
        }

        public func appendInterpolation<A>(_ paramIso: PartialIso<String, A>) where A: StringFormatting {
            appendParser(sparam(paramIso))
        }

        public func appendInterpolation<A>(_ paramIso: PartialIso<String, A>, index: UInt) where A: StringFormatting {
            appendParser(sparam(paramIso, index: index))
        }
    }

}
#endif

extension StringFormat {
    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: StringFormat, rhs: StringFormat<B>) -> StringFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func %> (x: StringFormat<Prelude.Unit>, y: StringFormat) -> StringFormat {
        return .init(x.parser %> y.parser)
    }
}

extension StringFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func <% <B>(x: StringFormat<B>, y: StringFormat) -> StringFormat<B> {
        return .init(x.parser <% y.parser)
    }
}

extension StringFormat {
    public static var end: StringFormat<Prelude.Unit> {
        return StringFormat<Prelude.Unit>(
            Parser(
                parse: { $0.isEmpty ? (.empty, unit) : nil },
                print: const(.empty),
                template: const(.empty)
            )
        )
    }
}

public protocol StringFormatting {
    static var format: String { get }
    var arg: CVarArg { get }
}

#if canImport(ObjectiveC)
extension NSObject: StringFormatting {
    static public var format: String { return "@" }
    public var arg: CVarArg { return self }
}
#endif

extension Prelude.Unit: StringFormatting {
    static public var format: String { return "" }
    public var arg: CVarArg { return NSString(string: "") }
}

extension Character: StringFormatting {
    static public var format: String { return "c" }
    public var arg: CVarArg { return UnicodeScalar(String(self))!.value }
}

extension String: StringFormatting {
    static public var format: String { return "@" }
    public var arg: CVarArg { return NSString(string: self) }
}

extension CChar: StringFormatting {
    static public var format: String { return "hhd" }
    public var arg: CVarArg { return self }
}

extension CShort: StringFormatting {
    static public var format: String { return "hd" }
    public var arg: CVarArg { return self }
}

extension CLong: StringFormatting {
    static public var format: String { return "ld" }
    public var arg: CVarArg { return self }
}

extension CLongLong: StringFormatting {
    static public var format: String { return "lld" }
    public var arg: CVarArg { return self }
}

#if os(macOS)
extension Float80: StringFormatting {
    static public var format: String { return "Lf" }
    #if swift(>=5.0)
    public var arg: CVarArg { return self }
    #else
    public var arg: CVarArg { return Float(self) }
    #endif
}
#else
extension Double: StringFormatting {
    static public var format: String { return "Lf" }
    public var arg: CVarArg { return self }
}
#endif

extension PartialIso where A == String, B: StringFormatting {
    public var formatted: PartialIso {
        return PartialIso(
            apply: apply,
            unapply: { _ in "%\(B.format)" }
        )
    }

    public func formatted(index: UInt) -> PartialIso {
        return PartialIso(
            apply: apply,
            unapply: { _ in "%\(index)$\(B.format)" }
        )
    }
}

func head<A>(_ xs: [A]) -> (A, [A])? {
    guard let x = xs.first else { return nil }
    return (x, Array(xs.dropFirst()))
}

public func slit(_ str: String) -> Parser<StringTemplate, Prelude.Unit> {
    return Parser<StringTemplate, Prelude.Unit>(
        parse: { format in
            head(format.template.parts).flatMap { (p, ps) in
                return p == str
                    ? (StringTemplate(template: Template(parts: ps), args: []), unit)
                    : nil
            }
    },
        print: { _ in StringTemplate(template: Template(parts: [str]), args: []) },
        template: { _ in StringTemplate(template: Template(parts: [str]), args: []) }
    )
}

public func slit(_ str: String) -> StringFormat<Prelude.Unit> {
    return StringFormat<Prelude.Unit>(slit(str))
}

private func _sparam<A: StringFormatting>(_ f: PartialIso<String, A>) -> Parser<StringTemplate, A> {
    return Parser<StringTemplate, A>(
        parse: { format in
            guard let (p, ps) = head(format.template.parts), let v = try f.apply(p) else { return nil }
            return (StringTemplate(template: Template(parts: ps), args: [v.arg]), v)
    },
        print: { a in
            try f.unapply(a).flatMap {
                StringTemplate(
                    template: Template(parts: [String(format: $0, a.arg)]),
                    args: [
                        a.arg
                    ]
                )
            }
    },
        template: { a in
            try f.unapply(a).flatMap {
                StringTemplate(
                    template: Template(parts: [$0]),
                    args: [
                        a.arg
                    ]
                )
            }
    })
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>) -> Parser<StringTemplate, A> {
    return _sparam(f.formatted)
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>, index: UInt) -> Parser<StringTemplate, A> {
    return _sparam(f.formatted(index: index))
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>) -> StringFormat<A> {
    return StringFormat<A>(sparam(f))
}

public func sparam<A: StringFormatting>(_ f: PartialIso<String, A>, index: UInt) -> StringFormat<A> {
    return StringFormat<A>(sparam(f, index: index))
}

extension StringFormat {

    public func render<A1, B>(_ a: A1, _ b: B) throws -> String? where A == (A1, B)
    {
        return try render((a, b))
    }

    public func localized<A1, B>(_ a: A1, _ b: B, table: String? = nil, bundle: Bundle = .main, value: String? = nil) throws -> String? where A == (A1, B)
    {
        return try localized((a, b), table: table, bundle: bundle, value: value)
    }

    public func template<A1, B>(_ a: A1, _ b: B) throws -> StringTemplate? where A == (A1, B)
    {
        return try self.print((a, b))
    }

    public func render<A1, B>(templateFor a: A1, _ b: B) throws -> String? where A == (A1, B)
    {
        return try self.parser.template((a, b)).flatMap { $0.render() }
    }

}

extension StringFormat {

    public func render<A1, B, C>(_ a: A1, _ b: B, _ c: C) throws -> String? where A == (A1, (B, C))
    {
        return try render(parenthesize(a, b, c))
    }

    public func localized<A1, B, C>(_ a: A1, _ b: B, _ c: C, table: String? = nil, bundle: Bundle = .main, value: String? = nil) throws -> String? where A == (A1, (B, C))
    {
        return try localized(parenthesize(a, b, c), table: table, bundle: bundle, value: value)
    }

    public func template<A1, B, C>(_ a: A1, _ b: B, _ c: C) throws -> StringTemplate? where A == (A1, (B, C))
    {
        return try self.print(parenthesize(a, b, c))
    }

    public func render<A1, B, C>(templateFor a: A1, _ b: B, _ c: C) throws -> String? where A == (A1, (B, C))
    {
        return try self.parser.template(parenthesize(a, b, c)).flatMap { $0.render() }
    }

}

extension StringFormat {

    public func render<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D) throws -> String? where A == (A1, (B, (C, D)))
    {
        return try render(parenthesize(a, b, c, d))
    }

    public func localized<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D, table: String? = nil, bundle: Bundle = .main, value: String? = nil) throws -> String? where A == (A1, (B, (C, D)))
    {
        return try localized(parenthesize(a, b, c, d), table: table, bundle: bundle, value: value)
    }

    public func template<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D) throws -> StringTemplate? where A == (A1, (B, (C, D)))
    {
        return try self.print(parenthesize(a, b, c, d))
    }

    public func render<A1, B, C, D>(templateFor a: A1, _ b: B, _ c: C, _ d: D) throws -> String? where A == (A1, (B, (C, D)))
    {
        return try self.parser.template(parenthesize(a, b, c, d)).flatMap { $0.render() }
    }

}
