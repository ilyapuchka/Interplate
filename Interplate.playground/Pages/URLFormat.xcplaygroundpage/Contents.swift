import Foundation
@testable import Interplate
import Prelude

let name = "playground"
let year = 2019

enum Routes: Equatable {
    case hello(name: String, year: Int)
}

extension Routes: Matchable {
    func match<A>(_ constructor: (A) -> Routes) -> A? {
        switch self {
        case let .hello(values as A) where self == constructor(values): return values
        default: return nil
        }
    }
}

var hello = "hello" </> path(.string) </> "year" </> path(.int)

let routes: URLFormat<Routes> =
    scheme("http") </> host("www.me.com") </> [
        iso(Routes.hello) <¢> hello,
        ].reduce(.empty, <|>)

routes.render(.hello(name: name, year: year))
let template = routes.template(for: .hello(name: name, year: year))!
template.template.parts
template.urlComponents.url
template.render()
routes.match(template)
