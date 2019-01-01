# Interplate
Templates based on Swift 5 string interpolation.

## Requirements

- Swift 5 toolchain

## About

Swift string interpolation already allows to use plain strings for the purpose of templates, i.e. you can not just inject value in a string, but use it with conditional and  functional operators like `?:` and `map`, which allows to express more complex cases common for templates:

```swift
"Hello \(names.map{ $0.capitalized }.joined(separator: ", "))!"
// Hello Foo, Bar!
```

Swift 5 string interpolation improvements allow to extend strings with a DSL suitable for templating, i.e. you can define a for-loop function which will allow a bit more control of interation progress than `map` (though it's possible to achieve the same with just `map` such expressions can become a bit complicated):

```swift
"Hello \(for: names, do: { name, loop in 
    "\(name)\(loop.index + 1 == loop.length - 1 ? " and " : ", ")"
})!"
// Hello Foo, Bar and FooBar!
```

This package supports following features:

- default value for optional variable `\(_: String?, default: String)`
- `for` loops `\(for: [T], where: (T) -> Bool, do: (T, LoopContext) -> Void, empty: @autoclosure () -> Template)`
- embedding other templates `\(_: Template)` or `\(include: String, notFound: @autoclosure () -> Template)`
- indentation `\(indent: Int, with: String, indentFirstLine: Bool, _: @autoclosure () -> Template)`
- trimming whitespaces or new lines `\(trim: CharacterSet)`
- templates inheritance based on Swift classes inheritance

## Usage

To create a template you define a subclass of `Renderer` class with a template markup in its `template` property and then you use this renderer to render the template. There you can access any variables you passed in the constructor or computed variables which replaces the notion of `context` and `blocks` common in other template engines.

```swift
class HelloWorld: Renderer {
    let names: [String]
    
    init(names: [String]) {
        self.names = names
    }

    var greetings: Template {
        return "Hello"
    }

    override var template: Template {
        return "\(greetings) \(names.map{ $0.capitalized }.joined(separator: ", "))!"
    }
}

let content = HelloWorld(names: ["Foo", "Bar"]).render()
//Hello Foo, Bar!
```

## Running tests

To run tests run `swift test`.

## Installation

You can install this package with Swift Package Manager.


