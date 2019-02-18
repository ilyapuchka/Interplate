import Foundation
import Prelude

public struct URLTemplate: TemplateType {
    public let template: Template
    let urlComponents: URLComponents

    init(template: Template, urlComponents: URLComponents) {
        self.template = template
        self.urlComponents = urlComponents
    }

    public static let empty: URLTemplate = URLTemplate(template: .empty, urlComponents: URLComponents())

    public static func <> (lhs: URLTemplate, rhs: URLTemplate) -> URLTemplate {
        return URLTemplate(template: lhs.template <> rhs.template, urlComponents: lhs.urlComponents <> rhs.urlComponents)
    }

    public var isEmpty: Bool {
        return template.isEmpty
    }

    public func render() -> String {
        return urlComponents
            //.with { $0.path = "/" + $0.path }
            .url?.absoluteString ?? ""
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
        result.queryItems =
            lhs.queryItems.flatMap { lhs in
                rhs.queryItems.flatMap { rhs in lhs + rhs }
                    ?? lhs
            }
            ?? rhs.queryItems
        return result
    }

    public var pathComponents: [String] {
        return path.components(separatedBy: "/")
    }

    func with(_ f: (inout URLComponents) -> Void) -> URLComponents {
        var v = self
        f(&v)
        return v
    }
}

public struct URLFormat<A>: FormatType, ExpressibleByStringInterpolation {
    public let parser: Parser<URLTemplate, A>

    public init(_ parser: Parser<URLTemplate, A>) {
        self.parser = parser
    }

    public func render(_ a: A) -> String? {
        return self.parser.print(a).flatMap { $0.render() }
    }

    public func match(_ template: URLTemplate) -> A? {
        return (self </> URLFormat.end).parser.parse(template)?.match
    }

    public init(stringLiteral value: String) {
        self.init(path(String(value)).map(.any))
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
        private(set) var parsers: [(Parser<URLTemplate, Any>, Any.Type)] = []

        public required init(literalCapacity: Int, interpolationCount: Int) {
        }

        public func appendParser<A>(_ parser: Parser<URLTemplate, A>) {
            if let parser = parser as? Parser<URLTemplate, Any> {
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

infix operator </>: infixr4
//infix operator />: infixr4
//infix operator </: infixr4

extension URLFormat {

    /// A Format that always fails and doesn't print anything.
    public static var empty: URLFormat {
        return .init(.empty)
    }

    public func map<B>(_ f: PartialIso<A, B>) -> URLFormat<B> {
        return .init(parser.map(f))
    }

    public static func <¢> <B> (lhs: PartialIso<A, B>, rhs: URLFormat) -> URLFormat<B> {
        return .init(lhs <¢> rhs.parser)
    }

    /// Processes with the left side Format, and if that fails uses the right side Format.
    public static func <|> (lhs: URLFormat, rhs: URLFormat) -> URLFormat {
        return .init(lhs.parser <|> rhs.parser)
    }

    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func </> <B> (lhs: URLFormat, rhs: URLFormat<B>) -> URLFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func </> (x: URLFormat<Prelude.Unit>, y: URLFormat) -> URLFormat {
        return .init(x.parser %> y.parser)
    }
}

extension URLFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func </> <B>(x: URLFormat<B>, y: URLFormat) -> URLFormat<B> {
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

public func path(_ str: String) -> Parser<URLTemplate, Prelude.Unit> {
    return Parser<URLTemplate, Prelude.Unit>(
        parse: { format in
            return head(format.template.parts).flatMap { (p, ps) in
                return p == str
                    ? (URLTemplate(template: Template(parts: ps), urlComponents: URLComponents()), unit)
                    : nil
            }
    },
        print: { _ in URLTemplate(template: Template(parts: [str]), urlComponents: URLComponents().with { $0.path = str }) },
        template: { _ in URLTemplate(template: Template(parts: [str]), urlComponents: URLComponents().with { $0.path = str }) }
    )
}

public func path(_ str: String) -> URLFormat<Prelude.Unit> {
    return URLFormat<Prelude.Unit>(path(str))
}

public func path<A>(_ f: PartialIso<String, A>) -> Parser<URLTemplate, A> {
    return Parser<URLTemplate, A>(
        parse: { format in
            guard let (p, ps) = head(format.template.parts), let v = f.apply(p) else { return nil }
            return (URLTemplate(template: Template(parts: ps), urlComponents: URLComponents()), v)
    },
        print: { a in
            f.unapply(a).flatMap { s in
                URLTemplate(template: Template(parts: [s]), urlComponents: URLComponents().with { $0.path = s })
            }
    },
        template: { a in
            f.unapply(a).flatMap { s in
                return URLTemplate(template: Template(parts: [":" + "\(type(of: a))"]), urlComponents: URLComponents().with { $0.path = s })
            }
    })
}

public func path<A>(_ f: PartialIso<String, A>) -> URLFormat<A> {
    return URLFormat<A>(path(f))
}

public func scheme(_ str: String) -> Parser<URLTemplate, Prelude.Unit> {
    return Parser<URLTemplate, Prelude.Unit>(
        parse: { format in
            return head(format.template.parts).flatMap { (p, ps) in
                return p == str
                    ? (URLTemplate(template: Template(parts: ps), urlComponents: URLComponents()), unit)
                    : nil
            }
    },
        print: { _ in URLTemplate(template: Template(parts: [str]), urlComponents: URLComponents().with { $0.scheme = str }) },
        template: { _ in URLTemplate(template: Template(parts: [str]), urlComponents: URLComponents().with { $0.scheme = str }) }
    )
}

public func scheme(_ str: String) -> URLFormat<Prelude.Unit> {
    return URLFormat<Prelude.Unit>(scheme(str))
}

public func host(_ str: String) -> Parser<URLTemplate, Prelude.Unit> {
    return Parser<URLTemplate, Prelude.Unit>(
        parse: { format in
            return head(format.template.parts).flatMap { (p, ps) in
                return p == str
                    ? (URLTemplate(template: Template(parts: ps), urlComponents: URLComponents()), unit)
                    : nil
            }
    },
        print: { _ in URLTemplate(template: Template(parts: [str]), urlComponents: URLComponents().with { $0.host = str }) },
        template: { _ in URLTemplate(template: Template(parts: [str]), urlComponents: URLComponents().with { $0.host = str }) }
    )
}

public func host(_ str: String) -> URLFormat<Prelude.Unit> {
    return URLFormat<Prelude.Unit>(host(str))
}

public func host(_ f: PartialIso<String, String>) -> Parser<URLTemplate, String> {
    return Parser<URLTemplate, String>(
        parse: { format in
            guard let (p, ps) = head(format.template.parts), let v = f.apply(p) else { return nil }
            return (URLTemplate(template: Template(parts: ps), urlComponents: URLComponents()), v)
    },
        print: { a in
            f.unapply(a).flatMap { s in
                URLTemplate(template: Template(parts: [s]), urlComponents: URLComponents().with { $0.host = s })
            }
    },
        template: { a in
            f.unapply(a).flatMap { s in
                return URLTemplate(template: Template(parts: [":" + "\(type(of: a))"]), urlComponents: URLComponents().with { $0.host = s })
            }
    })
}
