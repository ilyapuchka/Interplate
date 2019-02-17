import Foundation
@testable import Interplate
import Prelude

let name = "playground"
let year = 2019

enum Templates: Equatable {
    case hello(name: String, year: Int)
    case long(name: String, year: Int, name: String, year: Int)
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

("Hello, " %> any()).render("a")

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
templates.match(templates.template(for: .hello(name: name, year: year))!)
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
long_template.parts
long_template.render()
long.match(long_template).flatMap(flatten)
long.match(long_template) as (String, Int, String, Int)?

let f: Format<Any> = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
f.render(parenthesize(name, year, name, year))
f.match(long_template)

var loc = "Hello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <%> ".\nHello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <% "."

loc.render(parenthesize(name, year, name, year))
loc.render(templateFor: parenthesize(name, year, name, year))


loc = """
Hello, \(.string). Year is \(.int).
Hello, \(.string). Year is \(.int).
"""
loc.render(parenthesize(name, year, name, year))
loc.render(templateFor: parenthesize(name, year, name, year))
let locT = loc.template(for: parenthesize(name, year, name, year))!
locT.template.parts
loc.match(locT)


var locFormat = "Hello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <%> ".\nHello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <% "."
locFormat.format.render(parenthesize(name, year, name, year))
locFormat.format.render(templateFor: parenthesize(name, year, name, year))


locFormat = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
locFormat.format.render(parenthesize(name, year, name, year))
locFormat.format.render(templateFor: parenthesize(name, year, name, year))


let locAnyFormat: StringFormat<Any> = """
Hello, \(.string, index: 1). Year is \(.int, index: 2).
Hello, \(.string, index: 3). Year is \(.int, index: 4).
"""

locAnyFormat.render((name, (year, (name+name, year+1))))
locAnyFormat.render(templateFor: (name, (year, (name, year))))
let locAnyT = locAnyFormat.template(for: (name, (year, (name+name, year+1))))!
locAnyT.template.parts
locAnyFormat.match(locAnyT)

locAnyFormat.localized((name, (year, (name+name, year+1))))

let anyFormat: StringFormat<Character> = "Hello, \(.char)"
anyFormat.render("ü")
