import Foundation
import Prelude

public final class LocalizedTemplate: Monoid {
    public let template: Template
    public let args: [CVarArg]

    init(template: Template, args: [CVarArg]) {
        self.template = template
        self.args = args
    }

    public static var empty: LocalizedTemplate {
        return LocalizedTemplate(template: .empty, args: [])
    }

    public static func <> (lhs: LocalizedTemplate, rhs: LocalizedTemplate) -> LocalizedTemplate {
        return LocalizedTemplate(template: lhs.template <> rhs.template, args: lhs.args <> rhs.args)
    }

    func render() -> String {
        return template.render()
    }
}

public struct LocalizedFormat<A> {
    let parser: Parser<LocalizedTemplate, A>

    init(_ parser: Parser<LocalizedTemplate, A>) {
        self.parser = parser
    }

    init(
        parse: @escaping (LocalizedTemplate) -> (rest: LocalizedTemplate, match: A)?,
        print: @escaping (A) -> LocalizedTemplate?,
        template: @escaping (A) -> LocalizedTemplate?
        ) {
        self.init(Parser<LocalizedTemplate, A>(parse: parse, print: print, template: template))
    }

    public func localize(_ a: A, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String? {
        guard let template = parser.print(a) else { return nil }
        return String(
            format: bundle.localizedString(forKey: template.render(), value: value, table: table),
            arguments: template.args
        )
    }

    public func match(_ template: LocalizedTemplate) -> A? {
        return (self <% end).parser.parse(template)?.match
    }

    public func render(_ a: A) -> String? {
        return self.parser.print(a).flatMap { $0.render() }
    }

    public func template(for a: A) -> Template? {
        return self.parser.print(a)?.template
    }

    public func render(templateFor a: A) -> String? {
        return self.parser.template(a).flatMap { $0.render() }
    }
}

extension LocalizedFormat: ExpressibleByStringInterpolation {

    public init(stringLiteral value: String) {
        self.parser = llit(String(value)).map(.any)
    }

    public init(stringInterpolation: StringInterpolation) {
        if stringInterpolation.parsers.isEmpty {
            self.parser = .empty
        } else {
            let parser = reduce(parsers: stringInterpolation.parsers)
            self.parser = parser.map(.any)
        }
    }

    public class StringInterpolation: StringInterpolationProtocol {
        private(set) var parsers: [(Parser<LocalizedTemplate, Any>, Any.Type)] = []

        public required init(literalCapacity: Int, interpolationCount: Int) {
        }

        func appendParser<A>(_ parser: Parser<LocalizedTemplate, A>) {
            parsers.append((parser.map(.any), A.self))
        }

        public func appendLiteral(_ literal: String) {
            appendParser(llit(literal))
        }

        public func appendInterpolation<A: LocalizableStringInterpolatable>(_ paramIso: PartialIso<String, A>) {
            let iso = paramIso.loc
            appendParser(lparam(iso))
        }
    }

}

public protocol LocalizableStringInterpolatable {
    var localizableKeyFormat: String { get }
    var localizableArg: CVarArg { get }
}

extension String: LocalizableStringInterpolatable {
    public var localizableKeyFormat: String { return "%@" }
    public var localizableArg: CVarArg { return self }
}

extension Int: LocalizableStringInterpolatable {
    public var localizableKeyFormat: String { return "%lld" }
    public var localizableArg: CVarArg { return Int64(self) }
}

extension Prelude.Unit: LocalizableStringInterpolatable {
    public var localizableKeyFormat: String { return "" }
    public var localizableArg: CVarArg { return "" }
}

extension PartialIso where A == String, B: LocalizableStringInterpolatable {
    var loc: PartialIso {
        return PartialIso(
            apply: apply,
            unapply: { $0.localizableKeyFormat }
        )
    }
}

extension LocalizedFormat {

    /// A Format that always fails and doesn't print anything.
    public static var empty: LocalizedFormat {
        return .init(.empty)
    }

    public func map<B>(_ f: PartialIso<A, B>) -> LocalizedFormat<B> {
        return .init(parser.map(f))
    }

    public static func <¢> <B> (lhs: PartialIso<A, B>, rhs: LocalizedFormat) -> LocalizedFormat<B> {
        return .init(lhs <¢> rhs.parser)
    }

    /// Processes with the left side Format, and if that fails uses the right side Format.
    public static func <|> (lhs: LocalizedFormat, rhs: LocalizedFormat) -> LocalizedFormat {
        return .init(lhs.parser <|> rhs.parser)
    }

    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: LocalizedFormat, rhs: LocalizedFormat<B>) -> LocalizedFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func %> (x: LocalizedFormat<Prelude.Unit>, y: LocalizedFormat) -> LocalizedFormat {
        return .init(x.parser %> y.parser)
    }
}

extension LocalizedFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func <% <B>(x: LocalizedFormat<B>, y: LocalizedFormat) -> LocalizedFormat<B> {
        return .init(x.parser <% y.parser)
    }
}

private let end = LocalizedFormat<Prelude.Unit>(
    parse: { format in
        format.template.parts.isEmpty
            ? (LocalizedTemplate(template: Template(parts: []), args: []), unit)
            : nil
},
    print: const(.empty),
    template: const(.empty)
)

public func llit(_ str: String) -> Parser<LocalizedTemplate, Prelude.Unit> {
    return Parser<LocalizedTemplate, Prelude.Unit>(
        parse: { format in
            head(format.template.parts).flatMap { (p, ps) in
                return p == str
                    ? (LocalizedTemplate(template: Template(parts: ps), args: []), unit)
                    : nil
            }
    },
        print: { _ in LocalizedTemplate(template: Template(parts: [str]), args: []) },
        template: { _ in LocalizedTemplate(template: Template(parts: [str]), args: []) }
    )
}

public func llit(_ str: String) -> LocalizedFormat<Prelude.Unit> {
    return LocalizedFormat<Prelude.Unit>(llit(str))
}

public func lparam<A: LocalizableStringInterpolatable>(_ f: PartialIso<String, A>) -> Parser<LocalizedTemplate, A> {
    return Parser<LocalizedTemplate, A>(
        parse: { format in
            guard let (p, ps) = head(format.template.parts), let v = f.apply(p) else { return nil }
            return (LocalizedTemplate(template: Template(parts: ps), args: [v.localizableArg]), v)
    },
        print: { a in
            f.unapply(a).flatMap {
                LocalizedTemplate(template: Template(parts: [$0]), args: [a.localizableArg])
            }
    },
        template: { a in
            f.unapply(a).flatMap {
                LocalizedTemplate(template: Template(parts: [$0]), args: [a.localizableArg])
            }
    })
}

public func lparam<A: LocalizableStringInterpolatable>(_ f: PartialIso<String, A>) -> LocalizedFormat<A> {
    return LocalizedFormat<A>(lparam(f))
}

extension LocalizedFormat {

    public func localize<A1, B>(_ a: A1, _ b: B, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String?
        where
        A == (A1, B),
        A1: LocalizableStringInterpolatable,
        B: LocalizableStringInterpolatable {
            return localize((a, b), table: table, bundle: bundle, value: value)
    }

    public func localize<A1, B, C>(_ a: A1, _ b: B, _ c: C, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String?
        where
        A == (A1, (B, C)),
        A1: LocalizableStringInterpolatable,
        B: LocalizableStringInterpolatable,
        C: LocalizableStringInterpolatable
    {
        return localize((a, (b, c)), table: table, bundle: bundle, value: value)
    }

    public func localize<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D, table: String? = nil, bundle: Bundle = .main, value: String? = nil) -> String?
        where
        A == (A1, (B, (C, D))),
        A1: LocalizableStringInterpolatable,
        B: LocalizableStringInterpolatable,
        C: LocalizableStringInterpolatable,
        D: LocalizableStringInterpolatable
    {
        return localize((a, (b, (c, d))), table: table, bundle: bundle, value: value)
    }

}
