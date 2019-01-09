//  Based on:
//  https://github.com/pointfreeco/swift-web/blob/master/Sources/ApplicativeFormatter/SyntaxFormatter.swift
//

import Foundation

extension Template {
    public static let empty: Template = ""

    static func <>(lhs: Template, rhs: Template) -> Template {
        return .init(
            parts: lhs.parts + rhs.parts
        )
    }
}

public struct StringFormatter<A> {

    public let parse: (Template) -> (rest: Template, match: A)?
    public let print: (A) -> Template?
    public let template: (A) -> Template?

    public func match(format: Template) -> A? {
        return (self <% end).parse(format)?.match
    }

    public func render(_ a: A) -> String? {
        return self.print(a).flatMap { $0.render() }
    }

    public func template(for a: A) -> String? {
        return self.template(a).flatMap { $0.render() }
    }

}

extension StringFormatter: ExpressibleByStringInterpolation {

    public typealias UnicodeScalarLiteralType = String.UnicodeScalarLiteralType

    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self = lit(String(value)).map(.any)
    }

    public typealias ExtendedGraphemeClusterLiteralType = String.ExtendedGraphemeClusterLiteralType

    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self = lit(String(value)).map(.any)
    }

    public init(stringLiteral value: String) {
        self = lit(String(value)).map(.any)
    }

    public init(stringInterpolation: StringFormatter.StringInterpolation) {
        if stringInterpolation.formatters.isEmpty {
            self = .empty
        } else if stringInterpolation.formatters.count == 1 {
            self = stringInterpolation.formatter.map(.any)
        } else {
            var (composed, lastType) = stringInterpolation.formatters.last!
            stringInterpolation.formatters.dropLast().reversed().forEach { (f, prevType) in
                if lastType == Unit.self { // A <% ()
                    (composed, lastType) = (f <% composed.map(.any), prevType)
                } else if prevType == Unit.self { // () %> A
                    composed = f.map(.any) %> composed
                } else { // A <%> B
                    (composed, lastType) = (.any <¢> f <%> composed, prevType)
                }
            }
            self = composed.map(.any)
        }
    }

    public class StringInterpolation: StringInterpolationProtocol {
        private(set) var formatter: StringFormatter<Any>!
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
    /// Processes with the left and right side StringFormatters, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: StringFormatter, rhs: StringFormatter<B>) -> StringFormatter<(A, B)> {
        return StringFormatter<(A, B)>(
            parse: { str in
                guard let (more, a) = lhs.parse(str) else { return nil }
                guard let (rest, b) = rhs.parse(more) else { return nil }
                return (rest, (a, b))
        },
            print: { ab in
                let lhsPrint = lhs.print(ab.0)
                let rhsPrint = rhs.print(ab.1)
                return (curry(<>) <¢> lhsPrint <*> rhsPrint) ?? lhsPrint ?? rhsPrint
        },
            template: { ab in
                let lhsPrint = lhs.template(ab.0)
                let rhsPrint = rhs.template(ab.1)
                return (curry(<>) <¢> lhsPrint <*> rhsPrint) ?? lhsPrint ?? rhsPrint
        })
    }

    /// Processes with the left and right side StringFormatters, discarding the result of the left side.
    public static func %> (x: StringFormatter<Interplate.Unit>, y: StringFormatter) -> StringFormatter {
        return (PartialIso.commute >>> PartialIso.unit.inverted) <¢> x <%> y
    }
}

extension StringFormatter where A == Interplate.Unit {
    /// Processes with the left and right StringFormatters, discarding the result of the right side.
    public static func <% <B>(x: StringFormatter<B>, y: StringFormatter) -> StringFormatter<B> {
        return PartialIso.unit.inverted <¢> x <%> y
    }
}


func head<A>(_ xs: [A]) -> (A, [A])? {
    guard let x = xs.first else { return nil }
    return (x, Array(xs.dropFirst()))
}

func head<C: Collection>(_ xs: C) -> (C.Element, C.SubSequence)? {
    guard let head = xs.first else { return nil }
    return (head, xs.dropFirst())
}

public func lit(_ str: String) -> StringFormatter<Interplate.Unit> {
    return StringFormatter<Interplate.Unit>(
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
            Template(parts: ["\\(\(typeKey(a)))"])
    })
}

public let end = StringFormatter<Interplate.Unit>(
    parse: { format in
        format.parts.isEmpty
            ? (Template(parts: []), unit)
            : nil
},
    print: const(.empty),
    template: const(.empty)
)

extension StringFormatter {
    public func map<B>(_ f: PartialIso<A, B>) -> StringFormatter<B> {
        return f <¢> self
    }

    public static func <¢> <B> (lhs: PartialIso<A, B>, rhs: StringFormatter) -> StringFormatter<B> {
        return StringFormatter<B>(
            parse: { route in
                guard let (rest, match) = rhs.parse(route) else { return nil }
                return lhs.apply(match).map { (rest, $0) }
        },
            print: lhs.unapply >=> rhs.print,
            template: lhs.unapply >=> rhs.template
        )
    }
}

extension StringFormatter {
    /// Processes with the left side StringFormatter, and if that fails uses the right side StringFormatter.
    public static func <|> (lhs: StringFormatter, rhs: StringFormatter) -> StringFormatter {
        return .init(
            parse: { lhs.parse($0) ?? rhs.parse($0) },
            print: { lhs.print($0) ?? rhs.print($0) },
            template: { lhs.template($0) ?? rhs.template($0) }
        )
    }
}

extension StringFormatter {
    /// A StringFormatter that always fails and doesn't print anything.
    public static var empty: StringFormatter {
        return StringFormatter(
            parse: const(nil),
            print: const(nil),
            template: const(nil)
        )
    }
}

private func typeKey<A>(_ a: A) -> String {
    // todo: convert camel case to snake case?
    let typeString = "\(type(of: a))"
    let typeKey: String
    if typeString.contains("Optional<") {
        typeKey = "optional_\(typeString)"
            .replacingOccurrences(of: "Optional<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .lowercased()
    } else if typeString.contains("Either<") {
        typeKey = "\(typeString)"
            .replacingOccurrences(of: "Either<", with: "")
            .replacingOccurrences(of: ", ", with: "_or_")
            .replacingOccurrences(of: ">", with: "")
            .lowercased()
    } else {
        typeKey = typeString.lowercased()
    }

    return typeKey
}

public func render<A, B>(_ formatter: StringFormatter<(A, B)>, _ a: A, _ b: B) -> String {
    return formatter.render((a, b))!
}

public func render<A, B, C>(_ formatter: StringFormatter<(A, (B, C))>, _ a: A, _ b: B, _ c: C) -> String {
    return formatter.map(flatten()).render((a, b, c))!
}

public func render<A, B, C, D>(_ formatter: StringFormatter<(A, (B, (C, D)))>, _ a: A, _ b: B, _ c: C, _ d: D) -> String {
    return formatter.map(flatten()).render((a, b, c, d))!
}
