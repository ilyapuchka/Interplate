import Foundation
import Interplate

let name = "playground"
let year = 2019

enum Templates: Equatable {
    case hello(name: String, year: Int)

    enum iso {
        static let hello = parenthesize(PartialIso(
            apply: Templates.hello,
            unapply: {
                guard case let .hello(result) = $0 else { return nil }
                return result
            }
        ))
    }
}

var t: Template = "Hello, \(name). Year is \(year)."

var hello = "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."

hello.render((name, year))
hello.match(format: t)
hello.template(for: (name, year))

let templates: StringFormatter<Templates> = [
    Templates.iso.hello <¢> hello
].reduce(.empty, <|>)

templates.render(.hello(name: name, year: year))
templates.match(format: t)
templates.template(for: .hello(name: name, year: year))

hello = "Hello, \(.string). Year is \(.int)."
hello.render((name, year))
render(hello, name, year)

t = "Hello, \(name). Year is \(year).\nHello, \(name). Year is \(year)."
var long: StringFormatter<(String, (Int, (String, Int)))> =
    "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <%> ".\nHello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."

long.map(flatten()).render((name, year, name, year))
long.match(format: t)

long = "Hello, \(.string). Year is \(.int).\nHello, \(.string). Year is \(.int)."
long.map(flatten()).render((name, year, name, year))
long.match(format: t)

render(long, name, year, name, year)
let f: StringFormatter<Any> = "Hello, \(.string). Year is \(.int).\nHello, \(.string). Year is \(.int)."
print(f.render((name, (year, (name, year)))))
