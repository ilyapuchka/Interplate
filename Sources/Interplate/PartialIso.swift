//  Based on:
//  https://github.com/pointfreeco/swift-web/blob/master/Sources/ApplicativeRouter/PartialIso.swift
//

import Foundation

precedencegroup infixl0 {
    associativity: left
    higherThan: AssignmentPrecedence
}
precedencegroup infixr0 {
    associativity: right
    higherThan: infixl0
}
precedencegroup infixl1 {
    associativity: left
    higherThan: infixr0
}
precedencegroup infixr1 {
    associativity: right
    higherThan: infixl1
}
precedencegroup infixl2 {
    associativity: left
    higherThan: infixr1
}
precedencegroup infixr2 {
    associativity: right
    higherThan: infixl2
}
precedencegroup infixl3 {
    associativity: left
    higherThan: infixr2
}
precedencegroup infixr3 {
    associativity: right
    higherThan: infixl3
}
precedencegroup infixl4 {
    associativity: left
    higherThan: infixr3
}
precedencegroup infixr4 {
    associativity: right
    higherThan: infixl4
}
precedencegroup infixl5 {
    associativity: left
    higherThan: infixr4
}
precedencegroup infixr5 {
    associativity: right
    higherThan: infixl5
    lowerThan: AdditionPrecedence
}
precedencegroup infixl6 {
    associativity: left
    higherThan: infixr5
}
precedencegroup infixr6 {
    associativity: right
    higherThan: infixl6
    lowerThan: MultiplicationPrecedence
}
precedencegroup infixl7 {
    associativity: left
    higherThan: infixr6
}
precedencegroup infixr7 {
    associativity: right
    higherThan: infixl7
}
precedencegroup infixl8 {
    associativity: left
    higherThan: infixr7
}
precedencegroup infixr8 {
    associativity: right
    higherThan: infixl8
}
precedencegroup infixl9 {
    associativity: left
    higherThan: infixr8
}
precedencegroup infixr9 {
    associativity: right
    higherThan: infixl9
}

infix operator >=>: infixr1

infix operator <|>: infixl3

infix operator <¢>: infixl4
// Apply
infix operator <*>: infixl4
// Apply (right-associative)
infix operator <%>: infixr4
infix operator %>: infixr4
infix operator <%: infixr4

infix operator <>: infixr5

infix operator >>>: infixr9
infix operator <<<: infixr9


public struct PartialIso<A, B> {
    public let apply: (A) -> B?
    public let unapply: (B) -> A?

    public init(apply: @escaping (A) -> B?, unapply: @escaping (B) -> A?) {
        self.apply = apply
        self.unapply = unapply
    }

    /// Inverts the partial isomorphism.
    public var inverted: PartialIso<B, A> {
        return .init(apply: self.unapply, unapply: self.apply)
    }

    /// A partial isomorphism between `(A, B)` and `(B, A)`.
    public static var commute: PartialIso<(A, B), (B, A)> {
        return .init(
            apply: { ($1, $0) },
            unapply: { ($1, $0) }
        )
    }

    /// Composes two partial isomorphisms.
    public static func >>> <C> (lhs: PartialIso<A, B>, rhs: PartialIso<B, C>) -> PartialIso<A, C> {
        return .init(
            apply: lhs.apply >=> rhs.apply,
            unapply: rhs.unapply >=> lhs.unapply
        )
    }

    /// Backwards composes two partial isomorphisms.
    public static func <<< <C> (lhs: PartialIso<B, C>, rhs: PartialIso<A, B>) -> PartialIso<A, C> {
        return .init(
            apply: rhs.apply >=> lhs.apply,
            unapply: lhs.unapply >=> rhs.unapply
        )
    }
}

func flatMap <A, B, C>(_ lhs: @escaping (B) -> ((A) -> C), _ rhs: @escaping (A) -> B) -> (A) -> C {
    return { a in
        lhs(rhs(a))(a)
    }
}

func >=> <A, B, C, D>(lhs: @escaping (A) -> ((D) -> B), rhs: @escaping (B) -> ((D) -> C))
    -> (A)
    -> ((D) -> C) {
        return { a in
            flatMap(rhs, lhs(a))
        }
}

func flatMap<A, B>(_ a2b: @escaping (A) -> B?) -> (A?) -> B? {
    return { a in
        a.flatMap(a2b)
    }
}

func >>> <A, B, C>(_ a2b: @escaping (A) -> B, _ b2c: @escaping (B) -> C) -> (A) -> C {
    return { a in b2c(a2b(a)) }
}

func >=> <A, B, C>(lhs: @escaping (A) -> B?, rhs: @escaping (B) -> C?) -> (A) -> C? {
    return lhs >>> flatMap(rhs)
}

extension PartialIso where B == A {
    /// The identity partial isomorphism.
    static var id: PartialIso {
        return .init(apply: { $0 }, unapply: { $0 })
    }
}

extension PartialIso where B == (A, Interplate.Unit) {
    /// An isomorphism between `A` and `(A, Unit)`.
    static var unit: PartialIso {
        return .init(
            apply: { ($0, Interplate.unit) },
            unapply: { $0.0 }
        )
    }
}

/// Converts a partial isomorphism of a flat 1-tuple to one of a right-weighted nested tuple.
public func parenthesize<A, B>(_ f: PartialIso<A, B>) -> PartialIso<A, B> {
    return f
}

/// Converts a partial isomorphism of a flat 2-tuple to one of a right-weighted nested tuple.
public func parenthesize<A, B, C>(_ f: PartialIso<(A, B), C>) -> PartialIso<(A, B), C> {
    return f
}

/// Converts a partial isomorphism of a flat 3-tuple to one of a right-weighted nested tuple.
public func parenthesize<A, B, C, D>(_ f: PartialIso<(A, B, C), D>) -> PartialIso<(A, (B, C)), D> {
    return flatten() >>> f
}

/// Converts a partial isomorphism of a flat 4-tuple to one of a right-weighted nested tuple.
public func parenthesize<A, B, C, D, E>(_ f: PartialIso<(A, B, C ,D), E>) -> PartialIso<(A, (B, (C, D))), E> {
    return flatten() >>> f
}

// TODO: should we just bite the bullet and create our own `TupleN` types and stop using Swift tuples
// altogether?
/// Flattens a right-weighted nested 3-tuple.
public func flatten<A, B, C>() -> PartialIso<(A, (B, C)), (A, B, C)> {
    return .init(
        apply: { ($0.0, $0.1.0, $0.1.1) },
        unapply: { ($0, ($1, $2)) }
    )
}

/// Flattens a left-weighted nested 4-tuple.
public func flatten<A, B, C, D>() -> PartialIso<(A, (B, (C, D))), (A, B, C, D)> {
    return .init(
        apply: { ($0.0, $0.1.0, $0.1.1.0, $0.1.1.1) },
        unapply: { ($0, ($1, ($2, $3))) }
    )
}

func id<A>(_ a: A) -> A {
    return a
}

public func const<A, B>(_ a: A) -> (B) -> A {
    return { _ in a }
}

func curry<A, B, C>(_ function: @escaping (A, B) -> C)
    -> (A)
    -> (B)
    -> C {
        return { (a: A) -> (B) -> C in
            { (b: B) -> C in
                function(a, b)
            }
        }
}

extension Optional {
    public static func <¢> <A>(f: (Wrapped) -> A, x: Optional) -> A? {
        return x.map(f)
    }
}

public func map<A, B>(_ a2b: @escaping (A) -> B) -> (A?) -> B? {
    return { a in
        a2b <¢> a
    }
}

extension Optional {
    public func apply<A>(_ f: ((Wrapped) -> A)?) -> A? {
        // return f.flatMap(self.map) // https://bugs.swift.org/browse/SR-5422
        guard let f = f, let a = self else { return nil }
        return f(a)
    }

    public static func <*> <A>(f: ((Wrapped) -> A)?, x: Optional) -> A? {
        return x.apply(f)
    }
}

public func apply<A, B>(_ a2b: ((A) -> B)?) -> (A?) -> B? {
    return { a in
        a2b <*> a
    }
}

extension Optional {
    public enum iso {
        /// A partial isomorphism `(A) -> A?`
        static var some: PartialIso<Wrapped, Wrapped?> {
            return .init(
                apply: Optional.some,
                unapply: id
            )
        }
    }
}

public func opt<A, B>(_ f: PartialIso<A, B>) -> PartialIso<A?, B?> {
    return PartialIso<A?, B?>(
        apply: { $0.flatMap(f.apply) },
        unapply: { $0.flatMap(f.unapply) }
    )
}

public func req<A, B>(_ f: PartialIso<A, B>) -> PartialIso<A?, B> {
    return Optional.iso.some.inverted >>> f
}

extension PartialIso where B == Any {
    public static var any: PartialIso {
        return PartialIso(
            apply: { $0 },
            unapply: { ($0 as! A) }
        )
    }
}

extension PartialIso where A == Any {
    public static var any: PartialIso {
        return PartialIso(
            apply: { ($0 as! B) },
            unapply: { $0 }
        )
    }
}

extension PartialIso {
    public static var any: PartialIso {
        return PartialIso(
            apply: { ($0 as! B) },
            unapply: { ($0 as! A) }
        )
    }
}

extension PartialIso where A == String, B == Int {
    /// An isomorphism between strings and integers.
    public static var int: PartialIso {
        return PartialIso(
            apply: { Int.init($0) },
            unapply: String.init(describing:)
        )
    }
}

extension PartialIso where A == String, B == Bool {
    /// An isomorphism between strings and booleans.
    public static var bool: PartialIso {
        return .init(
            apply: {
                $0 == "true" || $0 == "1" ? true
                    : $0 == "false" || $0 == "0" ? false
                    : nil
        },
            unapply: { $0 ? "true" : "false" }
        )
    }
}

extension PartialIso where A == String, B == String {
    /// The identity isomorphism between strings.
    public static var string: PartialIso {
        return .id
    }
}

extension PartialIso where A == String, B == Double {
    /// An isomorphism between strings and doubles.
    public static var double: PartialIso {
        return PartialIso(
            apply: Double.init,
            unapply: String.init(describing:)
        )
    }
}

extension PartialIso where B: RawRepresentable, B.RawValue == A {
    public static var rawRepresentable: PartialIso {
        return .init(
            apply: B.init(rawValue:),
            unapply: { $0.rawValue }
        )
    }
}

extension PartialIso where A == String, B == UUID {
    public static var uuid: PartialIso<String, UUID> {
        return PartialIso(
            apply: UUID.init(uuidString:),
            unapply: { $0.uuidString }
        )
    }
}

extension PartialIso where A: Codable, B == Data {
    public static func codableToJsonData(
        _ type: A.Type,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
        )
        -> PartialIso {

            return .init(
                apply: { try? encoder.encode($0) },
                unapply: { try? decoder.decode(type, from: $0) }
            )
    }
}

public let jsonDictionaryToData = PartialIso<[String: String], Data>(
    apply: { try? JSONSerialization.data(withJSONObject: $0) },
    unapply: {
        (try? JSONSerialization.jsonObject(with: $0))
            .flatMap { $0 as? [String: String] }
})

//extension PartialIso where A == String, B: Collection {
//    public static func array() -> PartialIso {
//        return PartialIso(apply: { (string) in
//            return B
//        }, unapply: { (l) -> String? in
//            return String(describing: l)
//        })
//    }
//}
//
//public func array<A>() -> PartialIso<String, [A]> {
//    return PartialIso<String, [A]>(
//        apply: { (string) -> [A]? in
//            return nil
//    },
//        unapply: { (array) -> String? in
//            return nil
//    }
//    )
//}

public func first<A>(where predicate: @escaping (A) -> Bool) -> PartialIso<[A], A> {
    return PartialIso<[A], A>(
        apply: { $0.first(where: predicate) },
        unapply: { [$0] }
    )
}

public func filter<A>(_ isIncluded: @escaping (A) -> Bool) -> PartialIso<[A], [A]> {
    return PartialIso<[A], [A]>(
        apply: { $0.filter(isIncluded) },
        unapply: id
    )
}

public func key<K, V>(_ key: K) -> PartialIso<[K: V], V> {
    return PartialIso<[K: V], V>(
        apply: { $0[key] },
        unapply: { [key: $0] }
    )
}

public func keys<K, V>(_ keys: [K]) -> PartialIso<[K: V], [K: V]> {
    return .init(
        apply: { $0.filter { key, _ in keys.contains(key) } },
        unapply: id
    )
}

public struct Unit: Codable {}
public let unit = Unit()
