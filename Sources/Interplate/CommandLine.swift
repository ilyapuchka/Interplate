import Foundation
import Prelude

public struct CommandLineArguments {
    public private(set) var parts: [String]

    public init(parts: [String] = CommandLine.arguments) {
        self.parts = parts
    }
}

extension CommandLineArguments: Monoid {
    public static var empty: CommandLineArguments {
        return CommandLineArguments(parts: [])
    }

    public static func <> (lhs: CommandLineArguments, rhs: CommandLineArguments) -> CommandLineArguments {
        return CommandLineArguments(parts: lhs.parts + rhs.parts)
    }
}

extension CommandLineArguments: TemplateType {
    public var isEmpty: Bool {
        return parts.isEmpty
    }

    public func render() -> String {
        return parts.joined(separator: " ")
    }
}

public struct CommandLineFormat<A>: FormatType {
    public let parser: Parser<CommandLineArguments, A>

    public init(_ parser: Parser<CommandLineArguments, A>) {
        self.parser = parser
    }

    public static var empty: CommandLineFormat {
        return .init(.empty)
    }

    public func match(_ template: CommandLineArguments) -> A? {
        return self.parser.parse(template)?.match
    }

    public func match(_ args: [String] = CommandLine.arguments) -> A? {
        return self.match(CommandLineArguments(parts: args))
    }
}

extension CommandLineFormat {
    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: CommandLineFormat, rhs: CommandLineFormat<B>) -> CommandLineFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func <%> (x: CommandLineFormat<Prelude.Unit>, y: CommandLineFormat) -> CommandLineFormat {
        return .init(x.parser %> y.parser)
    }
}

extension CommandLineFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func <%> <B>(x: CommandLineFormat<B>, y: CommandLineFormat) -> CommandLineFormat<B> {
        return .init(x.parser <% y.parser)
    }
}

public func command(_ str: String) -> Parser<CommandLineArguments, Prelude.Unit> {
    return Parser<CommandLineArguments, Prelude.Unit>(
        parse: { format in
            return head(format.parts).flatMap { (p, ps) in
                return p == str
                    ? (CommandLineArguments(parts: ps), unit)
                    : nil
            }
    },
        print: { _ in CommandLineArguments(parts: [str]) },
        template: { _ in CommandLineArguments(parts: [str]) }
    )
}

public func command(_ str: String) -> CommandLineFormat<Prelude.Unit> {
    return CommandLineFormat<Prelude.Unit>(command(str))
}

public func arg<A>(long: String, short: String?, _ f: PartialIso<String, A>) -> Parser<CommandLineArguments, A> {
    return Parser<CommandLineArguments, A>(
        parse: { format in
            guard
                let p = format.parts.index(where: { $0 == "--\(long)" || $0 == "-\(short ?? "-\(long)")" }),
                p < format.parts.endIndex,
                let v = f.apply(format.parts[format.parts.index(after: p)])
                else { return nil }
            return (format, v)
    },
        print: { a in
            f.unapply(a).flatMap { s in CommandLineArguments(parts: ["--\(long)", s]) }
    },
        template: { a in
            f.unapply(a).flatMap { s in CommandLineArguments(parts: ["--\(long)", "\(type(of: a))"]) }
    })
}

public func arg<A>(long: String, short: String? = nil, _ f: PartialIso<String, A>) -> CommandLineFormat<A> {
    return CommandLineFormat<A>(arg(long: long, short: short, f))
}

public func arg<A>(long: String, short: String?, _ f: PartialIso<String?, A?>) -> Parser<CommandLineArguments, A?> {
    return Parser<CommandLineArguments, A?>(
        parse: { format in
            guard
                let p = format.parts.index(where: { $0 == "--\(long)" || $0 == "-\(short ?? "-\(long)")" }),
                p < format.parts.endIndex,
                let v = f.apply(format.parts[format.parts.index(after: p)])
                else { return (format, nil) }
            return (format, v)
    },
        print: { a in
            f.unapply(a).flatMap { s in CommandLineArguments(parts: ["--\(long)", s ?? ""]) }
            ?? .empty
    },
        template: { a in
            f.unapply(a).flatMap { s in CommandLineArguments(parts: ["--\(long)", "\(type(of: a))"]) }
            ?? .empty
    })
}

public func arg<A>(long: String, short: String? = nil, _ f: PartialIso<String?, A?>) -> CommandLineFormat<A?> {
    return CommandLineFormat<A?>(arg(long: long, short: short, f))
}

public func option(long: String, short: String?) -> Parser<CommandLineArguments, Bool> {
    return Parser<CommandLineArguments, Bool>(
        parse: { format in
            let v = format.parts.contains(where: { $0 == "--\(long)" || $0 == "-\(short ?? "-\(long)")" })
            return (format, v)
    },
        print: { $0 ? CommandLineArguments(parts: ["--\(long)"]) : .empty },
        template: { $0 ? CommandLineArguments(parts: ["--\(long)"]) : .empty }
    )
}

public func option(long: String, short: String? = nil) -> CommandLineFormat<Bool> {
    return CommandLineFormat<Bool>(option(long: long, short: short))
}
