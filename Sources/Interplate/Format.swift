import Foundation
import Prelude

public protocol TemplateType: Monoid {
    var isEmpty: Bool { get }
    func render() -> String
}

public protocol FormatType {
    associatedtype T: TemplateType
    associatedtype A

    var parser: Parser<T, A> { get }
    init(_ parser: Parser<T, A>)
}

extension FormatType {
    /// A Format that always fails and doesn't print anything.
    public static var empty: Self {
        return .init(.empty)
    }

    /// Processes with the left side Format, and if that fails uses the right side Format.
    public static func <|> (lhs: Self, rhs: Self) -> Self {
        return .init(lhs.parser <|> rhs.parser)
    }

    public func map<F: FormatType, B>(_ f: PartialIso<A, B>) -> F
        where F.A == B, F.T == T {
            return .init(parser.map(f))
    }

    public static func <¢> <F: FormatType, B> (lhs: PartialIso<A, B>, rhs: Self) -> F
        where F.A == B, F.T == T {
            return .init(lhs <¢> rhs.parser)
    }
}

extension FormatType {
    init(
        parse: @escaping (T) -> (rest: T, match: A)?,
        print: @escaping (A) -> T?,
        template: @escaping (A) -> T?
    ) {
        self.init(Parser<T, A>(parse: parse, print: print, template: template))
    }

    public func render(_ a: A) -> String? {
        return self.parser.print(a).flatMap { $0.render() }
    }

    public func render(templateFor a: A) -> String? {
        return self.parser.template(a).flatMap { $0.render() }
    }

    public func template(for a: A) -> T? {
        return self.parser.print(a)
    }
}

public struct Format<A>: FormatType {

    public let parser: Parser<Template, A>

    public init(_ parser: Parser<Template, A>) {
        self.parser = parser
    }

    public func match(_ template: Template) -> A? {
        return (self <% Format.end).parser.parse(template)?.match
    }

}

#if swift(>=5.0)
extension Format: ExpressibleByStringInterpolation {

    public init(stringLiteral value: String) {
        self.init(lit(String(value)).map(.any))
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
        private(set) var parsers: [(Parser<Template, Any>, Any.Type)] = []

        public required init(literalCapacity: Int, interpolationCount: Int) {
        }

        public func appendParser<A>(_ parser: Parser<Template, A>) {
            if let parser = parser as? Parser<Template, Any> {
                parsers.append((parser, A.self))
            } else {
                parsers.append((parser.map(.any), A.self))
            }
        }

        public func appendLiteral(_ literal: String) {
            guard literal.isEmpty == false else { return }
            appendParser(lit(literal))
        }

        public func appendInterpolation<A>(_ paramIso: PartialIso<String, A>) {
            appendParser(param(paramIso))
        }
    }
}
#endif

extension Format {
    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: Format, rhs: Format<B>) -> Format<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func %> (x: Format<Prelude.Unit>, y: Format) -> Format {
        return .init(x.parser %> y.parser)
    }
}

extension Format where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func <% <B>(x: Format<B>, y: Format) -> Format<B> {
        return .init(x.parser <% y.parser)
    }
}

extension Format {
    public static var end: Format<Prelude.Unit> {
        return Format<Prelude.Unit>(
            parse: { format in
                format.isEmpty
                    ? (.empty, unit)
                    : nil
        },
            print: const(.empty),
            template: const(.empty)
        )
    }
}

public func lit(_ str: String) -> Parser<Template, Prelude.Unit> {
    return Parser<Template, Prelude.Unit>(
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

public func lit(_ str: String) -> Format<Prelude.Unit> {
    return Format<Prelude.Unit>(lit(str))
}

public func param<A>(_ f: PartialIso<String, A>) -> Parser<Template, A> {
    return Parser<Template, A>(
        parse: { format in
            guard let (p, ps) = head(format.parts), let v = f.apply(p) else { return nil }
            return (Template(parts: ps), v)
    },
        print: { a in
            f.unapply(a).flatMap {
                Template(parts: [$0])
            }
    },
        template: { a in
            f.unapply(a).flatMap { _ in
                Template(parts: ["\\(\(type(of: a)))"])
            }
    })
}

public func param<A>(_ f: PartialIso<String, A>) -> Format<A> {
    return Format<A>(param(f))
}

public func any() -> Parser<Template, Any> {
    let f = PartialIso<String, Any>.any
    return param(f)
}

public func any() -> Format<Any> {
    return Format(any())
}

extension Format {

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

extension Format {

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

extension Format {

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
