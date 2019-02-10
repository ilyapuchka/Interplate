//  Based on:
//  https://github.com/pointfreeco/swift-web/blob/master/Sources/ApplicativeFormatter/SyntaxFormatter.swift
//

import Foundation
import Prelude

public struct Parser<T: Monoid, A> {
    public let parse: (T) -> (rest: T, match: A)?
    public let print: (A) -> T?
    public let template: (A) -> T?
}

extension Parser {
    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: Parser, rhs: Parser<T, B>) -> Parser<T, (A, B)> {
        return Parser<T, (A, B)>(
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

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func %> (x: Parser<T, Prelude.Unit>, y: Parser) -> Parser {
        return (PartialIso.commute >>> PartialIso.unit.inverted) <¢> x <%> y
    }
}

extension Parser where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func <% <B>(x: Parser<T, B>, y: Parser) -> Parser<T, B> {
        return PartialIso.unit.inverted <¢> x <%> y
    }
}

extension Parser {
    public func map<B>(_ f: PartialIso<A, B>) -> Parser<T, B> {
        return f <¢> self
    }

    public static func <¢> <B> (lhs: PartialIso<A, B>, rhs: Parser) -> Parser<T, B> {
        return Parser<T, B>(
            parse: { route in
                guard let (rest, match) = rhs.parse(route) else { return nil }
                return lhs.apply(match).map { (rest, $0) }
        },
            print: lhs.unapply >=> rhs.print,
            template: lhs.unapply >=> rhs.template
        )
    }
}

extension Parser {

    public static func <|> (lhs: Parser, rhs: Parser) -> Parser {
        return .init(
            parse: { lhs.parse($0) ?? rhs.parse($0) },
            print: { lhs.print($0) ?? rhs.print($0) },
            template: { lhs.template($0) ?? rhs.template($0) }
        )
    }

    /// A Parser that always fails and doesn't print anything.
    public static var empty: Parser {
        return Parser(
            parse: const(nil),
            print: const(nil),
            template: const(nil)
        )
    }
}
