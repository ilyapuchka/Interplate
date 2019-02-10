import Foundation
import Prelude

extension Template: Monoid {
    public static let empty: Template = ""

    public static func <>(lhs: Template, rhs: Template) -> Template {
        return .init(
            parts: lhs.parts + rhs.parts
        )
    }
}

public struct StringFormatter<A> {

    public let parser: Parser<Template, A>

    public init(_ parser: Parser<Template, A>) {
        self.parser = parser
    }

    public init(
        parse: @escaping (Template) -> (rest: Template, match: A)?,
        print: @escaping (A) -> Template?,
        template: @escaping (A) -> Template?
    ) {
        self.init(Parser<Template, A>(parse: parse, print: print, template: template))
    }

    public func match(_ template: Template) -> A? {
        return (self <% end).parser.parse(template)?.match
    }

    public func render(_ a: A) -> String? {
        return self.parser.print(a).flatMap { $0.render() }
    }

    public func template(for a: A) -> Template? {
        return self.parser.print(a)
    }

    public func render(templateFor a: A) -> String? {
        return self.parser.template(a).flatMap { $0.render() }
    }
}

extension StringFormatter: ExpressibleByStringInterpolation {

    public init(stringLiteral value: String) {
        self = lit(String(value)).map(.any)
    }

    public init(stringInterpolation: StringFormatter.StringInterpolation) {
        if stringInterpolation.formatters.isEmpty {
            self = .empty
        } else if stringInterpolation.formatters.count == 1 {
            self = stringInterpolation.formatters[0].0.map(.any)
        } else {
            var (composed, lastType) = stringInterpolation.formatters.last!
            stringInterpolation.formatters.dropLast().reversed().forEach { (f, prevType) in
                if lastType == Prelude.Unit.self { // A <% ()
                    (composed, lastType) = (f <% composed.map(.any), prevType)
                } else if prevType == Prelude.Unit.self { // () %> A
                    composed = f.map(.any) %> composed
                } else { // A <%> B
                    (composed, lastType) = (.any <¢> f <%> composed, prevType)
                }
            }
            self = composed.map(.any)
        }
    }

    public class StringInterpolation: StringInterpolationProtocol {
        private(set) var formatters: [(StringFormatter<Any>, Any.Type)] = []

        public required init(literalCapacity: Int, interpolationCount: Int) {
        }

        public func appendFormatter<A>(_ formatter: StringFormatter<A>) {
            formatters.append((formatter.map(.any), A.self))
        }

        public func appendLiteral(_ literal: String) {
            guard literal.isEmpty == false else { return }
            appendFormatter(lit(literal))
        }

        public func appendInterpolation(_ literal: String) {
            appendLiteral(literal)
        }

        public func appendInterpolation<A>(_ paramIso: PartialIso<String, A>) {
            appendFormatter(param(paramIso))
        }
    }
}

extension StringFormatter {

    /// A StringFormatter that always fails and doesn't print anything.
    public static var empty: StringFormatter {
        return .init(.empty)
    }

    public func map<B>(_ f: PartialIso<A, B>) -> StringFormatter<B> {
        return .init(parser.map(f))
    }

    public static func <¢> <B> (lhs: PartialIso<A, B>, rhs: StringFormatter) -> StringFormatter<B> {
        return .init(lhs <¢> rhs.parser)
    }

    /// Processes with the left side StringFormatter, and if that fails uses the right side StringFormatter.
    public static func <|> (lhs: StringFormatter, rhs: StringFormatter) -> StringFormatter {
        return .init(lhs.parser <|> rhs.parser)
    }

    /// Processes with the left and right side StringFormatters, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: StringFormatter, rhs: StringFormatter<B>) -> StringFormatter<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side StringFormatters, discarding the result of the left side.
    public static func %> (x: StringFormatter<Prelude.Unit>, y: StringFormatter) -> StringFormatter {
        return .init(x.parser %> y.parser)
    }
}

extension StringFormatter where A == Prelude.Unit {
    /// Processes with the left and right StringFormatters, discarding the result of the right side.
    public static func <% <B>(x: StringFormatter<B>, y: StringFormatter) -> StringFormatter<B> {
        return .init(x.parser <% y.parser)
    }
}

public let end: StringFormatter<Prelude.Unit> = StringFormatter<Prelude.Unit>(
    parse: { format in
        format.parts.isEmpty
            ? (Template(parts: []), unit)
            : nil
    },
    print: const(.empty),
    template: const(.empty)
)

public func lit(_ str: String) -> StringFormatter<Prelude.Unit> {
    return StringFormatter<Prelude.Unit>(
        parse: { format in
            head(format.parts).flatMap { (p, ps) in
                return p == str
                    ? (Template(parts: ps), unit)
                    : nil
            }
        },
        print: { _ in .init(parts: [str]) },
        template: { _ in .init(parts: [str]) }
    )
}

public func param<A>(_ f: PartialIso<String, A>) -> StringFormatter<A> {
    return StringFormatter<A>(
        parse: { format in
            guard let (p, ps) = head(format.parts), let v = f.apply(p) else { return nil }
            return (Template(parts: ps), v)
    },
        print: { a in
            Template(parts: [f.unapply(a) ?? ""])
    },
        template: { a in
            Template(parts: ["\\(\(type(of: a)))"])
    })
}

extension StringFormatter {

    public func render<A1, B>(_ a: A1, _ b: B) -> String? where A == (A1, B) {
        return self.render((a, b))
    }

    public func template<A1, B>(for a: A1, _ b: B) -> Template? where A == (A1, B) {
        return self.parser.print((a, b))
    }

    public func render<A1, B>(templateFor a: A1, _ b: B) -> String? where A == (A1, B) {
        return self.parser.template((a, b)).flatMap { $0.render() }
    }

}

extension StringFormatter {

    public func render<A1, B, C>(_ a: A1, _ b: B, _ c: C) -> String? where A == (A1, (B, C)) {
        return self.render(parenthesize(a, b, c))
    }

    public func render<A1, B, C>(_ a: (A1, B, C)) -> String? where A == (A1, (B, C)) {
        return self.render(parenthesize(a.0, a.1, a.2))
    }

    public func template<A1, B, C>(for a: A1, _ b: B, _ c: C) -> Template? where A == (A1, (B, C)) {
        return self.parser.print(parenthesize(a, b, c))
    }

    public func template<A1, B, C>(for a: (A1, B, C)) -> Template? where A == (A1, (B, C)) {
        return self.parser.print(parenthesize(a.0, a.1, a.2))
    }

    public func render<A1, B, C>(templateFor a: A1, _ b: B, _ c: C) -> String? where A == (A1, (B, C)) {
        return self.parser.template(parenthesize(a, b, c)).flatMap { $0.render() }
    }

    public func render<A1, B, C>(templateFor a: (A1, B, C)) -> String? where A == (A1, (B, C)) {
        return self.parser.template(parenthesize(a.0, a.1, a.2)).flatMap { $0.render() }
    }

    public func match<A1, B, C>(_ template: Template) -> (A1, B, C)? where A == (A1, (B, C)) {
        return match(template).flatMap(flatten)
    }

}

extension StringFormatter {

    public func render<A1, B, C, D>(_ a: A1, _ b: B, _ c: C, _ d: D) -> String? where A == (A1, (B, (C, D))) {
        return self.render(parenthesize(a, b, c, d))
    }

    public func render<A1, B, C, D>(_ a: (A1, B, C, D)) -> String? where A == (A1, (B, (C, D))) {
        return self.render(parenthesize(a.0, a.1, a.2, a.3))
    }

    public func template<A1, B, C, D>(for a: A1, _ b: B, _ c: C, _ d: D) -> Template? where A == (A1, (B, (C, D))) {
        return self.parser.print(parenthesize(a, b, c, d))
    }

    public func template<A1, B, C, D>(for a: (A1, B, C, D)) -> Template? where A == (A1, (B, (C, D))) {
        return self.parser.print(parenthesize(a.0, a.1, a.2, a.3))
    }

    public func render<A1, B, C, D>(templateFor a: A1, _ b: B, _ c: C, _ d: D) -> String? where A == (A1, (B, (C, D))) {
        return self.parser.template(parenthesize(a, b, c, d)).flatMap { $0.render() }
    }

    public func render<A1, B, C, D>(templateFor a: (A1, B, C, D)) -> String? where A == (A1, (B, (C, D))) {
        return self.parser.template(parenthesize(a.0, a.1, a.2, a.3)).flatMap { $0.render() }
    }

    public func match<A1, B, C, D>(_ template: Template) -> (A1, B, C, D)? where A == (A1, (B, (C, D))) {
        return match(template).flatMap(flatten)
    }

}
