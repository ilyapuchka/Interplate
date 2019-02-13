import Foundation
import Interplate
import Prelude

let name = "playground"
let year = 2019

enum Templates: Equatable {
    case hello(name: String, year: Int)
    case long(name: String, year: Int, name: String, year: Int)

    enum _iso {
        static let hello = parenthesize(PartialIso(
            apply: Templates.hello,
            unapply: {
                guard case let .hello(result) = $0 else { return nil }
                return result
            }
        ))
    }

}

extension Templates: Matchable {
    func match<A>(_ constructor: (A) -> Templates) -> A? {
        switch self {
        case let .hello(values as A) where self == constructor(values): return values
        case let .long(values as A) where self == constructor(values): return values
        default: return nil
        }
    }
}

var t: Template = "Hello, \(name). Year is \(year)."

var hello = "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."
var long = "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <%> ".\nHello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."

hello.render((name, year))
hello.render(name, year)
hello.match(t)
hello.template(for: (name, year))
hello.template(for: name, year)

let templates: Format<Templates> = [
    iso(Templates.hello) <¢> hello,
    iso(Templates.long) <¢> "Hello, \(.string). Year is \(.int).\nHello, \(.string). Year is \(.int)."
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

templates.render(.long(name: name, year: year, name: name, year: year))
templates.match(t)

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

var loc: LocalizedFormat<(String, (Int, (String, Int)))> = """
Hello, \(.string). Year is \(.int).
Hello, \(.string). Year is \(.int).
"""
loc.localize(name, year, name, year)
loc.render(templateFor: parenthesize(name, year, name, year))



loc = "Hello, " %> lparam(.string) <%> ". Year is " %> lparam(.int) <%> ".\nHello, " %> lparam(.string) <%> ". Year is " %> lparam(.int) <% "."

loc.localize(name, year, name, year)
loc.render(templateFor: parenthesize(name, year, name, year))


var locFormat = localized("Hello, " %> lparam(.string) <%> ". Year is " %> lparam(.int) <%> ".\nHello, " %> lparam(.string) <%> ". Year is " %> lparam(.int) <% ".")
locFormat.render(parenthesize(name, year, name, year))
locFormat.render(templateFor: parenthesize(name, year, name, year))


locFormat = localized("""
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """)
locFormat.render(parenthesize(name, year, name, year))
locFormat.render(templateFor: parenthesize(name, year, name, year))



let locAnyFormat: Format<Any> = localized("""
Hello, \(.string). Year is \(.int).
Hello, \(.string). Year is \(.int).
""")
locAnyFormat.render((name, (year, (name, year))))
locAnyFormat.render(templateFor: (name, (year, (name, year))))

