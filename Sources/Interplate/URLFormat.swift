import Foundation
import Prelude

extension URLComponents: TemplateType {
    public var isEmpty: Bool {
        return pathComponents.isEmpty && scheme == nil && host == nil
    }

    public func render() -> String {
        return url?.absoluteString ?? ""
    }
}

extension URLComponents: Monoid {
    public static var empty: URLComponents = URLComponents()

    public static func <>(lhs: URLComponents, rhs: URLComponents) -> URLComponents {
        var result = URLComponents()
        result.scheme = lhs.scheme ?? rhs.scheme
        result.host = lhs.host ?? rhs.host
        result.path = [lhs.path, rhs.path]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        if lhs.host != nil && rhs.host == nil {
            result.path = "/" + result.path
        }

        result.queryItems =
            lhs.queryItems.flatMap { lhs in
                rhs.queryItems.flatMap { rhs in lhs + rhs }
                    ?? lhs
            }
            ?? rhs.queryItems
        return result
    }

    public var pathComponents: [String] {
        get {
            if path.isEmpty {
                return []
            } else if path.hasPrefix("/") {
                return path.dropFirst().components(separatedBy: "/")
            } else {
                return path.components(separatedBy: "/")
            }
        }
        set {
            path = newValue.joined(separator: "/")
        }
    }

    func with(_ f: (inout URLComponents) -> Void) -> URLComponents {
        var v = self
        f(&v)
        return v
    }
}

public struct URLFormat<A>: FormatType, ExpressibleByStringLiteral {
    public let parser: Parser<URLComponents, A>

    public init(_ parser: Parser<URLComponents, A>) {
        self.parser = parser
    }

    public init(stringLiteral value: String) {
        self.init(path(String(value)).map(.any))
    }

    public func render(_ a: A) -> String? {
        return self.parser.print(a).flatMap { $0.render() }
    }

    public func match(_ template: URLComponents) -> A? {
        return (self </> URLFormat.end).parser.parse(template)?.match
    }

}

#if swift(>=5.0)
extension URLFormat: ExpressibleByStringInterpolation {

    public init(stringInterpolation: StringInterpolation) {
        if stringInterpolation.parsers.isEmpty {
            self.init(.empty)
        } else {
            let parser = reduce(parsers: stringInterpolation.parsers)
            self.init(parser.map(.any))
        }
    }

    public class StringInterpolation: StringInterpolationProtocol {
        private(set) var parsers: [(Parser<URLComponents, Any>, Any.Type)] = []

        public required init(literalCapacity: Int, interpolationCount: Int) {
        }

        public func appendParser<A>(_ parser: Parser<URLComponents, A>) {
            if let parser = parser as? Parser<URLComponents, Any> {
                parsers.append((parser, A.self))
            } else {
                parsers.append((parser.map(.any), A.self))
            }
        }

        public func appendLiteral(_ literal: String) {
            guard literal.isEmpty == false else { return }
            appendParser(path(literal))
        }

        public func appendInterpolation<A>(_ paramIso: PartialIso<String, A>) {
            appendParser(path(paramIso))
        }
    }
}
#endif

infix operator </>: infixr4
infix operator <?>: infixr4
infix operator <&>: infixr4

extension URLFormat {
    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func </> <B> (lhs: URLFormat, rhs: URLFormat<B>) -> URLFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func </> (x: URLFormat<Prelude.Unit>, y: URLFormat) -> URLFormat {
        return .init(x.parser %> y.parser)
    }

    public static func <?> <B> (lhs: URLFormat, rhs: URLFormat<B>) -> URLFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    public static func <?> (x: URLFormat<Prelude.Unit>, y: URLFormat) -> URLFormat {
        return .init(x.parser %> y.parser)
    }

    public static func <&> <B> (lhs: URLFormat, rhs: URLFormat<B>) -> URLFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    public static func <&> (x: URLFormat<Prelude.Unit>, y: URLFormat) -> URLFormat {
        return .init(x.parser %> y.parser)
    }
}

extension URLFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func </> <B>(x: URLFormat<B>, y: URLFormat) -> URLFormat<B> {
        return .init(x.parser <% y.parser)
    }
    
    public static func <?> <B>(x: URLFormat<B>, y: URLFormat) -> URLFormat<B> {
        return .init(x.parser <% y.parser)
    }

    public static func <&> <B>(x: URLFormat<B>, y: URLFormat) -> URLFormat<B> {
        return .init(x.parser <% y.parser)
    }
}

extension URLFormat {
    public static var end: URLFormat<Prelude.Unit> {
        return URLFormat<Prelude.Unit>(
            parse: { format in
                return format.isEmpty
                    ? (.empty, unit)
                    : nil
        },
            print: const(.empty),
            template: const(.empty)
        )
    }
}

public func path(_ str: String) -> Parser<URLComponents, Prelude.Unit> {
    return Parser<URLComponents, Prelude.Unit>(
        parse: { format in
            return head(format.pathComponents).flatMap { (p, ps) in
                return p == str
                    ? (format.with { $0.pathComponents = ps }, unit)
                    : nil
            }
    },
        print: { _ in URLComponents().with { $0.path = str } },
        template: { _ in URLComponents().with { $0.path = str } }
    )
}

public func path(_ str: String) -> URLFormat<Prelude.Unit> {
    return URLFormat<Prelude.Unit>(path(str))
}

public func path<A>(_ f: PartialIso<String, A>) -> Parser<URLComponents, A> {
    return Parser<URLComponents, A>(
        parse: { format in
            guard let (p, ps) = head(format.pathComponents), let v = f.apply(p) else { return nil }
            return (format.with { $0.pathComponents = ps }, v)
    },
        print: { a in
            f.unapply(a).flatMap { s in
                URLComponents().with { $0.path = s }
            }
    },
        template: { a in
            return f.unapply(a).flatMap { s in
                return URLComponents().with { $0.path = ":" + "\(type(of: a))" }
            }
    })
}

public func path<A>(_ f: PartialIso<String, A>) -> URLFormat<A> {
    return URLFormat<A>(path(f))
}

public func query<A>(_ key: String, _ f: PartialIso<String, A>) -> Parser<URLComponents, A> {
    return Parser<URLComponents, A>(
        parse: { format in
            guard
                let queryItems = format.queryItems,
                let p = queryItems.first(where: { $0.name == key })?.value,
                let v = f.apply(p)
                else { return nil }
            return (format, v)
    },
        print: { a in
            f.unapply(a).flatMap { s in
                URLComponents().with { $0.queryItems = [URLQueryItem(name: key, value: s)] }
            }
    },
        template: { a in
            f.unapply(a).flatMap { s in
                URLComponents().with { $0.queryItems = [URLQueryItem(name: key, value: ":" + "\(type(of: a))")] }
            }
    })
}

public func query<A>(_ key: String, _ f: PartialIso<String, A>) -> URLFormat<A> {
    return URLFormat<A>(query(key, f))
}

public func scheme(_ str: String) -> Parser<URLComponents, Prelude.Unit> {
    return Parser<URLComponents, Prelude.Unit>(
        parse: { format in
            return format.scheme.flatMap { (scheme) in
                return scheme == str
                    ? (format.with { $0.scheme = nil }, unit)
                    : nil
            }
    },
        print: { _ in URLComponents().with { $0.scheme = str } },
        template: { _ in URLComponents().with { $0.scheme = str } }
    )
}

public func scheme(_ str: String) -> URLFormat<Prelude.Unit> {
    return URLFormat<Prelude.Unit>(scheme(str))
}

public func host(_ str: String) -> Parser<URLComponents, Prelude.Unit> {
    return Parser<URLComponents, Prelude.Unit>(
        parse: { format in
            return format.host.flatMap { (host) in
                return host == str
                    ? (format.with { $0.host = nil }, unit)
                    : nil
            }
    },
        print: { _ in URLComponents().with { $0.host = str } },
        template: { _ in URLComponents().with { $0.host = str } }
    )
}

public func host(_ str: String) -> URLFormat<Prelude.Unit> {
    return URLFormat<Prelude.Unit>(host(str))
}

public func host(_ f: PartialIso<String, String>) -> Parser<URLComponents, String> {
    return Parser<URLComponents, String>(
        parse: { format in
            return format.host.flatMap { (host) in
                f.apply(host).flatMap { v in
                    (format.with { $0.host = nil }, v)
                }
            }
    },
        print: { a in
            f.unapply(a).flatMap { s in
                URLComponents().with { $0.host = s }
            }
    },
        template: { a in
            f.unapply(a).flatMap { s in
                return URLComponents().with { $0.host = ":" + "\(type(of: a))" }
            }
    })
}
