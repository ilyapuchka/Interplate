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
    public let usage: (A) -> String
    public let example: [A]
    public let parser: Parser<CommandLineArguments, A>

    public init(_ parser: Parser<CommandLineArguments, A>) {
        self.parser = parser
        self.usage = String.init(describing:)
        self.example = []
    }

    public init(
        parser: Parser<CommandLineArguments, A>,
        usage: @escaping (A) -> String,
        example: [A]
    ) {
        self.parser = parser
        self.usage = usage
        self.example = example
    }

    public static var empty: CommandLineFormat {
        return .init(parser: .empty, usage: const(""), example: [])
    }

    public func match(_ template: CommandLineArguments) -> A? {
        return self.parser.parse(template)?.match
    }

    public func match(_ args: [String] = CommandLine.arguments) -> A? {
        return self.match(CommandLineArguments(parts: args))
    }

    public func help() -> String {
        return example
            .compactMap {
                guard let example = render($0) else { return nil }
                return "\(usage($0))\n\nExample:\n  \(example)"
            }
            .joined(separator: "\n\n")
    }
}

private func argHelp<A>(parser: Parser<CommandLineArguments, A>, desc: String, example: A?) -> String {
    guard
        let example = example,
        let template = parser.template(example)?.parts.joined(separator: " ")
        else { return "" }
    return "  \(template): \(desc)"
}

extension CommandLineFormat {
    public static func <|> (lhs: CommandLineFormat, rhs: CommandLineFormat) -> CommandLineFormat {
        return CommandLineFormat<A>(
            parser: lhs.parser <|> rhs.parser,
            usage: { example in
                return [
                    lhs.usage(example),
                    rhs.usage(example)
                    ]
                    .filter({ !$0.isEmpty })
                    .joined(separator: "\n\n")
        },
            example: lhs.example + rhs.example
        )
    }

    public static func <¢> <B> (lhs: PartialIso<A, B>, rhs: CommandLineFormat) -> CommandLineFormat<B> {
        return CommandLineFormat<B>(
            parser: lhs <¢> rhs.parser,
            usage: { lhs.unapply($0).map(rhs.usage) ?? "" },
            example: rhs.example.compactMap(lhs.apply)
        )
    }

    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func <%> <B> (lhs: CommandLineFormat, rhs: CommandLineFormat<B>) -> CommandLineFormat<(A, B)> {
        return CommandLineFormat<(A, B)>(
            parser: lhs.parser <%> rhs.parser,
            usage: { lhs.usage($0.0) + "\n" + rhs.usage($0.1) },
            example: {
                guard let lhs = lhs.example.first, let rhs = rhs.example.first else { return [] }
                return [(lhs, rhs)]
        }()
        )
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
    public static func <%> (lhs: CommandLineFormat<Prelude.Unit>, rhs: CommandLineFormat) -> CommandLineFormat {
        return CommandLineFormat<A>(
            parser: lhs.parser %> rhs.parser,
            usage: { lhs.usage(unit) + "\n" + rhs.usage($0) },
            example: rhs.example
        )
    }
}

extension CommandLineFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func <%> <B>(lhs: CommandLineFormat<B>, rhs: CommandLineFormat) -> CommandLineFormat<B> {
        return CommandLineFormat<B>(
            parser: lhs.parser <% rhs.parser,
            usage: { lhs.usage($0) + "\n" + rhs.usage(unit) },
            example: lhs.example
        )
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

public func command(
    _ str: String,
    desc: String
) -> CommandLineFormat<Prelude.Unit> {
    return CommandLineFormat<Prelude.Unit>(
        parser: command(str),
        usage: const("\(str): \(desc)"),
        example: [unit]
    )
}

public func arg<A>(
    long: String,
    short: String?,
    _ f: PartialIso<String, A>
) -> Parser<CommandLineArguments, A> {
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
            f.unapply(a).flatMap { s in CommandLineArguments(parts: ["--\(long)\(short.map { " (-\($0))" } ?? "")", "\(type(of: a))"]) }
    })
}

public func arg<A>(
    _ long: String,
    short: String? = nil,
    _ f: PartialIso<String, A>,
    desc: String,
    example: A
) -> CommandLineFormat<A> {
    let parser = arg(long: long, short: short, f)
    return CommandLineFormat<A>(
        parser: parser,
        usage: { argHelp(parser: parser, desc: desc, example: $0) },
        example: [example]
    )
}

public func arg<A>(
    long: String,
    short: String?,
    _ f: PartialIso<String?, A?>
) -> Parser<CommandLineArguments, A?> {
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
            f.unapply(a).flatMap { s in CommandLineArguments(parts: ["--\(long)\(short.map { " (-\($0))" } ?? "")", "\(type(of: a))"]) }
            ?? .empty
    })
}

public func arg<A>(
    _ long: String,
    short: String? = nil,
    _ f: PartialIso<String?, A?>,
    desc: String,
    example: A
) -> CommandLineFormat<A?> {
    let parser = arg(long: long, short: short, f)
    return CommandLineFormat<A?>(
        parser: parser,
        usage: { argHelp(parser: parser, desc: desc, example: $0) },
        example: [example]
    )
}

public func option(
    long: String,
    short: String?
) -> Parser<CommandLineArguments, Bool> {
    return Parser<CommandLineArguments, Bool>(
        parse: { format in
            let v = format.parts.contains(where: { $0 == "--\(long)" || $0 == "-\(short ?? "-\(long)")" })
            return (format, v)
    },
        print: { $0 ? CommandLineArguments(parts: ["--\(long)"]) : .empty },
        template: { $0 ? CommandLineArguments(parts: ["--\(long)"]) : .empty }
    )
}

public func option(
    _ long: String,
    short: String? = nil,
    desc: String
) -> CommandLineFormat<Bool> {
    let parser = option(long: long, short: short)
    return CommandLineFormat<Bool>(
        parser: parser,
        usage: { argHelp(parser: parser, desc: desc, example: $0) },
        example: [true]
    )
}
