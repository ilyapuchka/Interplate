import Foundation
@testable import Interplate
import Prelude

let name = "playground"
let year = 2019

let args = [
    "hello", "--name", name, "--year", "\(year)", "--verbose"
    ]

//struct Commands: CustomPlaygroundDisplayConvertible {
//    enum Command {
//        case hello(name: String, year: Int?)
//    }
//
//    let command: Command
//
//    // Global options
//    let verbose: Bool
//
//    var playgroundDescription: Any {
//        return "\(command) verbose: \(verbose)"
//    }
//}
//
//extension Commands {
//    enum iso {
//        static let hello = parenthesize <| PartialIso(
//            apply: { args in
//                Commands(
//                    command: .hello(name: args.0, year: args.1),
//                    verbose: args.2
//                )
//        },
//            unapply: { cmd in
//                guard case let .hello(values) = cmd.command else { return nil }
//                return (values.0, values.1, cmd.verbose)
//        })
//    }
//}
//
//let commands: CommandLineFormat<Commands> = [
//    Commands.iso.hello
//        <¢> command("hello")
//        <%> arg(long: "name", .string)
//        <%> arg(long: "year", opt(.int))
//        <%> option(long: "verbose")
//    ].reduce(.empty, <|>)

enum Commands {
    case hello(name: String, year: Int?, verbose: Bool)
    case print
}

extension Commands: Matchable {
    func match<A>(_ constructor: (A) -> Commands) -> A? {
        switch self {
        case let .hello(values as A) where self == constructor(values): return values
        case .print:
            if let a = Prelude.unit as? A, constructor(a) == self {
                return a
            } else {
                return nil
            }
        default: return nil
        }
    }
}

let commands: CommandLineFormat<Commands> = [
    iso(Commands.hello)
        <¢> command(
            "hello",
            desc: "greeting"
        )
        <%> arg(
            long: "name", short: "n", .string,
            desc: "a name",
            example: "playground"
        )
        <%> arg(
            long: "year", short: "y", opt(.int),
            desc: "a year",
            example: 2019
        )
        <%> option(
            long: "verbose",
            desc: "be verbose"
        ),
    iso(Commands.print)
        <¢> command(
            "print",
            desc: "printing"
        )
    ].reduce(.empty, <|>)

print(commands.help())

commands.match(args)

var cmd = Commands.hello(name: name, year: year, verbose: true)
commands.render(cmd)
commands.match(commands.template(for: cmd)!)
commands.render(templateFor: cmd)
