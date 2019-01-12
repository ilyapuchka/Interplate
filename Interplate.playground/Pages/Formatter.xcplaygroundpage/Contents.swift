import Foundation
import Interplate
import Prelude

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
hello.match(t)
hello.template(for: (name, year))

let templates: StringFormatter<Templates> = [
    Templates.iso.hello <¢> hello
].reduce(.empty, <|>)

templates.render(.hello(name: name, year: year))
templates.match(t)
templates.template(for: .hello(name: name, year: year))

hello = "Hello, \(.string). Year is \(.int)."
render(hello, name, year)

t = "Hello, \(name). Year is \(year)."
match(hello, template: t)
render(hello, name, year)

t = """
    Hello, \(name). Year is \(year).
    Hello, \(name). Year is \(year).
    """
var long = "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <%> ".\nHello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."

render(long, name, year, name, year)
match(long, template: t)

long = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
render(long, name, year, name, year)
match(long, template: t)

render(long, name, year, name, year)
let f: StringFormatter<Any> = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
f.render((name, (year, (name, year))))
