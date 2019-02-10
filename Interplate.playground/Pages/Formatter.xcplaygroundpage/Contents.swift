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
hello.render(name, year)
hello.match(t)
hello.template(for: (name, year))
hello.template(for: name, year)

let templates: Format<Templates> = [
    Templates.iso.hello <¢> hello
].reduce(.empty, <|>)

templates.render(.hello(name: name, year: year))
templates.match(t)
templates.template(for: .hello(name: name, year: year))?.render()
templates.render(templateFor: .hello(name: name, year: year))

hello = "Hello, \(.string). Year is \(.int)."
hello.render((name, year))
hello.render(name, year)

t = "Hello, \(name). Year is \(year)."
hello.match(t)
hello.render((name, year))
hello.render(name, year)

t = """
    Hello, \(name). Year is \(year).
    Hello, \(name). Year is \(year).
    """
var long = "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <%> ".\nHello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."

long.render(parenthesize(name, year, name, year))
long.render(name, year, name, year)
long.match(t).flatMap(flatten)
long.match(t) as (String, Int, String, Int)?

long = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
long.render(parenthesize(name, year, name, year))
long.render(name, year, name, year)
long.match(t).flatMap(flatten)
long.match(t) as (String, Int, String, Int)?

let long_template = long.template(for: parenthesize(name, year, name, year+1))!
long_template.render()
long.match(long_template).flatMap(flatten)
long.match(long_template) as (String, Int, String, Int)?

let f: Format<Any> = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
f.render(parenthesize(name, year, name, year))
f.match(long_template)
