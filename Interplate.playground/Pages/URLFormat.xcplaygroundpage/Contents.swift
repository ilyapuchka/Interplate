import Foundation
@testable import Interplate
import Prelude
import CommonParsers

let name = "playground"
let year = 2019

enum Routes: Equatable {
    case hello(name: String, year: Int)
}

extension Routes: Matchable {
    func match<A>(_ constructor: (A) -> Routes) -> A? {
        switch self {
        case let .hello(values):
            guard let a = values as? A, self == constructor(a) else { return nil }
            return a
        }
    }
}

var hello = "hello" </> path(.string) </> "year" <?> query("year", .int)

let routes: URLFormat<Routes> =
    scheme("http") </> host("www.me.com") </> [
        iso(Routes.hello) <¢> hello,
        ].reduce(.empty, <|>)

routes.render(.hello(name: name, year: year))
routes.template(for: .hello(name: name, year: year))?.render()

routes.template(for: .hello(name: name, year: year))
let template = routes.print(.hello(name: name, year: year))
template?.path
template?.render()
template?.scheme
template?.host
template?.pathComponents
template?.queryItems
template.flatMap(routes.match)

