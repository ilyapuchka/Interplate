import Foundation
@testable import Interplate
import Prelude
import CommonParsers

let name = "playground"
let year = 2019

enum Templates: Equatable {
    case hello(name: String, year: Int)
    case long(name: String, year: Int, name: String, year: Int)
}

extension Templates: Matchable {
    func match<A>(_ constructor: (A) -> Templates) -> A? {
        switch self {
        case let .hello(values):
            guard let a = values as? A, self == constructor(a) else { return nil }
            return a
        case let .long(values):
            guard let a = values as? A, self == constructor(a) else { return nil }
            return a
        }
    }
}

try ("Hello, " %> any()).render("a")

var t: Template = "Hello, \(name). Year is \(year)."

var hello = "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."
var long = "Hello, " %> param(.string) <%> ". Year is " %> param(.int) <%> ".\nHello, " %> param(.string) <%> ". Year is " %> param(.int) <% "."

try hello.render((name, year))
try hello.render(name, year)
try hello.match(t)
try hello.template(for: (name, year))
try hello.template(for: name, year)

let templates: Format<Templates> = [
    iso(Templates.hello) <¢> hello,
    iso(Templates.long) <¢> long
]

try templates.render(.hello(name: name, year: year))
try templates.match(t)
try templates.match(templates.print(.hello(name: name, year: year))!)
try templates.template(for: .hello(name: name, year: year))?.render()

hello = "Hello, \(.string). Year is \(.int)."
try hello.render((name, year))
try hello.render(name, year)

t = "Hello, \(name). Year is \(year)."
try hello.match(t)
try hello.render((name, year))
try hello.render(name, year)

t = """
    Hello, \(name). Year is \(year).
    Hello, \(name). Year is \(year).
    """

try long.render(parenthesize(name, year, name, year))
try long.render(name, year, name, year)
try long.match(t).flatMap(flatten)
try long.match(t) as (String, Int, String, Int)?

long = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
try long.render(parenthesize(name, year, name, year))
try long.render(name, year, name, year)
try long.match(t).flatMap(flatten)
try long.match(t) as (String, Int, String, Int)?

try templates.render(.long(name: name, year: year, name: name, year: year))
try templates.match(t)

let long_template = try long.template(for: name, year, name, year+1)!
long_template.parts
long_template.render()
try long.match(long_template).flatMap(flatten)
try long.match(long_template) as (String, Int, String, Int)?

let f: Format<Any> = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
try f.render(parenthesize(name, year, name, year))
try f.match(long_template)

var loc = "Hello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <%> ".\nHello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <% "."

try loc.render(parenthesize(name, year, name, year))
try loc.template(for: parenthesize(name, year, name, year))?.render()


loc = """
Hello, \(.string). Year is \(.int).
Hello, \(.string). Year is \(.int).
"""
try loc.render(parenthesize(name, year, name, year))
try loc.template(for: parenthesize(name, year, name, year))?.render()
let locT = try loc.template(name, year, name, year)!
locT.template.parts
try loc.match(locT)


var locFormat = "Hello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <%> ".\nHello, " %> sparam(.string) <%> ". Year is " %> sparam(.int) <% "."
try locFormat.format.render(parenthesize(name, year, name, year))
try locFormat.format.template(for: parenthesize(name, year, name, year))?.render()


locFormat = """
    Hello, \(.string). Year is \(.int).
    Hello, \(.string). Year is \(.int).
    """
try locFormat.format.render(parenthesize(name, year, name, year))
try locFormat.format.template(for: parenthesize(name, year, name, year))?.render()


let locAnyFormat: StringFormat<Any> = """
Hello, \(.string, index: 1). Year is \(.int, index: 2).
Hello, \(.string, index: 3). Year is \(.int, index: 4).
"""

try locAnyFormat.render((name, (year, (name+name, year+1))))
try locAnyFormat.template(for: (name, (year, (name, year))))?.render()
let locAnyT = try locAnyFormat.template((name, (year, (name+name, year+1))))!

locAnyT.template.parts
try locAnyFormat.match(locAnyT)

try locAnyFormat.localized((name, (year, (name+name, year+1))))

let anyFormat: StringFormat<Character> = "Hello, \(.char)"
try anyFormat.render("ü")
