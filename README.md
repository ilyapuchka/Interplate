# Interplate
Templates and type-safe string formatting based on Swift 5 string interpolation.

## Requirements

- Swift 5 toolchain

## About

### Templates

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
- `for` loops `\(for: [T], where: (T) -> Bool, do: (T, LoopContext) -> Void, empty: @autoclosure () -> Template, join: (LoopContext) -> Template, keepEmptyLines: Bool)`
- embedding other templates `\(_: Template)` or `\(include: String, notFound: @autoclosure () -> Template)`
- indentation `\(indent: Int, with: String, indentFirstLine: Bool, keepEmptyLines: Bool, _: @autoclosure () -> Template)`
- trimming whitespaces or new lines `\(trim: CharacterSet, _: TrimDirection)`, `\(_trim: CharacterSet)`, `\(trim_: CharacterSet)`, `(_trim_: CharacterSet)`
- templates inheritance based on Swift class inheritance

### String formatting

Another application of string interpolation allows to implement type-safe (almost) string format API that will ensure that wrong type of parameter passed in to build the final string. implementation of this API is heavily based on [ApplicativeRouter](https://github.com/pointfreeco/swift-web/tree/master/Sources/ApplicativeRouter) by [Point-Free](https://www.pointfree.co). 

One way of using it is using operators: 

```swift
let hello = "Hello, " %> param(.string)
hello.render("Swift")
```

This will create a `Format<String>`, string formatter that will accept single `String` argument. Note that type of formatter can be dropped here - it will be inferred from type of parameter passed to `param` function.

Alternativy you can use string interpolation:

```swift
let hello: Format<String> = "Hello, \(.string)!"
hello.render("Swift")
```

This will create the same type of formatter, but type declaration is required here. This kind of formatter will not be type-safe in the same way as the first one. If the wrong type is used, i.e. if it is defined as `Format<Int>` instead, the code will compile but it will raise a runtime exception when rendering.

```swift
let hello: Format<Int> = "Hello, \(.string)!"
hello.render(0) // runtime error: Could not cast value of type 'Swift.Int' to 'Swift.String'
```

### LocalizedFormat

Similarly to `Format` you can use `LocalizedFormat` to create localized strings formats:

```swift
let hello: LocalizedFormat<String> = "Hello, \(.string)!"
hello.render(templateFor: "Swift")
// Hello, %@!

hello.render("Swift")
// Olá, Swift!
```

or you can use `localized` function that returns just a `Format`:

```swift
let hello: Format<String> = localized("Hello, \(.string)!")
hello.render(templateFor: "Swift")
// Hello, %@!

hello.render("Swift")
// Olá, Swift!
```

Internally it will call `Bundle.localizedString` method to get localized format string and will pass it as well as string parameter to `String(format:arguments:)` method to produce the final string.

To build strongly typed localized format with operators use `lparam` and `llit` functions instead of `param` and `lit`:

```swift
let hello = "Hello, " %> lparam(.string)
hello.render("Swift")
// Olá, Swift!
```


### Using `Template` and `Format` together

`Template` and `Format` can work together in an interesting way. If you have both a template and a formatter for the same string you can use the formatter to extract values from the template to find out values used to render it.

```swift
let name = "world"
let format: Format<String> = "Hello, \(.string)."
let template: Template = "Hello, \(name)."

let name = format.match(template)
//name = "world"
```

This is similar to matching regular expressions, but in a type-safe way. Formatter can also output a template-like string:
 
 ```swift
format.render(templateFor: name)
//Hello, \(String).
```

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

To create a string format you define a value of type `Format`.  If format uses two arguments, `A` and `B`, then formatter will expect a single argument of type `(A, B)`. In case of three arguments in the format, `A`, `B` and `C`, the type of the argument will be `(A, (B, C))` and so on. So as you can see types of individual arguments are grouped in pairs alligned to the right side. When rendering this format into string you can pass all parameters in an arguments list using `render` free function:

```swift
let format: StringFormat<(String, (Int, (String, Int)))> = 
    "Hello, \(.string). Today is \(.int) of \(.string) \(.int)"
    
let result = render(format, "world", 14, "Jan", 2019) 
//Hello, world. Today is 14 of Jan 2019
```

## Running tests

To run tests run `swift test`.

## Installation

You can install this package with Swift Package Manager.


