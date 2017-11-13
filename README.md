# Pancake

[![CI Status](http://img.shields.io/travis/zradke/Pancake.svg?style=flat)](https://travis-ci.org/zradke/Pancake)
[![Cocoapods Version](https://img.shields.io/cocoapods/v/Pancake.svg?style=flat)](http://cocoapods.org/pods/Pancake)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/Pancake.svg?style=flat)](http://cocoapods.org/pods/Pancake)
[![License](https://img.shields.io/cocoapods/l/Pancake.svg?style=flat)](http://cocoapods.org/pods/Pancake)

----

A flat cache implemented in Swift inspired by http://khanlou.com/2017/10/the-flat-cache/

## Features

- Use the `Cache` as the single source of truth
- Observe `Cached` values for changes over time
- Represent `Related` values that trigger observations
- Prune unobserved values as desired

## Requirements

- Xcode 9.0+
- Swift 4.0
- iOS 8.0+

## Installation

### [CocoaPods](http://cocoapods.org)

Add the following line to your `Podfile`:

```ruby
pod 'Pancake'
```

### [Carthage](https://github.com/Carthage/Carthage)

Add the following line to your `Cartfile`:

```ogdl
github "zradke/Pancake"
```

## Usage

### Create an `Identifiable` model

To be inserted in a `Cache`, a type need only be `Identifiable`:

```swift
struct Book: Identifiable {
    typealias ISBN = Int
    var identifier: ISBN
    var title: String
}
```

Any type can be used as the `Identifier` as long as it conforms to `CustomStringConvertible`, `Hashable`, and `Codable`. The `Cache` works best with value types rather than reference types, so prefer `struct` to `class` for both the model and `Identifier`.

### Add values to a `Cache`

Any `Identifiable` value can be inserted into a `Cache`:

```swift
let cache = Cache()
let book = Book(identifier: 9788700631625,
                title: "Harry Potter and the Sorcerer's Stone")
cache.set(book)
```

Once in a `Cache`, values can be retreived using the type's `Identifier`:

```swift
let retreivedBook: Book? = cache.get(9788700631625)
```

### Observe `Cached` values

Values in a `Cache` can also be wrapped as `Cached` values:

```swift
let cachedBook: Cached<Book> = cache.cached(9788700631625)
```

`Cached` values provide up-to-date values from a `Cache`, but also can be observed:

```swift
// Retreives the latest value from the `Cache`
let currentValue = cachedBook.value

// Executes the closure whenever the value is changed in the `Cache`
let disposable = cachedBook.observe { (book) in
    // update user interface etc.
}
```

Note that `CachedValue.observe(_:)` returns a `Cache.Disposable` which must be retained to keep the observation alive. Once it deallocates the observation automatically ends.

## Advanced usage

### `Mergeable` models

APIs often return incomplete representations of the same model. A `Cache` can slowly build up a complete model if the type is `Mergeable`:

```swift
struct Book: Identifiable, Mergeable {
    typealias ISBN = Int
    var identifier: ISBN
    var title: String?
    var publishedOn: Date?
    
    func merged(with other: Book) -> Book {
        var copy = self
        
        if let title = other.title { copy.title = title }
        if let publishedOn = other.publishedOn { copy.publishedOn = publishedOn }
        
        return copy
    }
}
```

When a `Mergeable` value is inserted into the cache, it is merged with any existing value:

```swift
let bookStub = Book(identifier: 9788700631625,
                    title: "Harry Potter and the Sorcerer's Stone",
                    publishedOn: nil)
cache.set(bookStub)

// Later from a different API...
let detailedBook = Book(identifier = 9788700631625,
                        title: nil,
                        publishedOn: "1998-09-01".toDate())
cache.set(detailedBook)

let compositeBook: Book = cache.get(9788700631625)!
compositeBook.title // "Harry Potter and the Sorcerer's Stone"
compositeBook.publishedOn // 1998-09-01
```

Creating the `Mergeable` implementations can be tedious with a large number of models, in which case [Sourcery](https://github.com/krzysztofzablocki/Sourcery) could be used.

### A model that `HasCachedRelationships`

Models often have relationships. The `Cache` can help normalize the data by storing a single representation of all values and allowing generalized relationships. A type indicates it has relationships by conforming to `HasCachedRelationships`, which is typically constructed by joining any `Related` properties:

```swift
struct Author: Identifiable, HasCachedRelationships {
   ...
   
   var books: Set<Related<Book>>
   
   var relatedCacheKeys: Set<CacheKey> {
       return books.map { $0.cacheKey }
   }
}

struct Book: Identifiable, HasCachedRelationships {
    ...
    
    var author: Related<Author>
    
    var relatedCacheKeys: Set<CacheKey> {
        return [author.cacheKey]
    }
}
```

`Related` values can be converted into `Cached` values using `Related.cached(in:)` to access their actualized value. However, a larger benefit of `HasCachedRelationships` is that observers are notified when related objects change in the cache, which allows UI that depends on a nested value to always stay in sync:

```swift
let cache = Cache()
var author = Author(identifier: 1,
                    name: "JK Rowling")
let book = Book(identifier: 9788700631625,
                title: "Harry Potter and the Sorcerer's Stone",
                author: Related(author))
author.books.append(Related(book))

cache.set(author)
cache.set(book)

let disposable = cache.cached(book).observe { (value) in
    // Update UI
}

author.bornOn = "1965-07-31".toDate()

cache.set(author) // Notifies the UI
```

The `Cache` is smart enough to handle circular relationships and relationships of any depth (although go too deep and you may have performance problems).

Similar to `Mergeable`, creating `HasCachedRelationships.relatedCacheKeys` usually involves boilerplate, so I suggest using [Sourcery](https://github.com/krzysztofzablocki/Sourcery) to help automate the process with large numbers of models.

### Batch updates

APIs often return related models in addition to the primary model which all need to be inserted in the `Cache` during processing. However, doing each as a separate call to `Cache` can have performance impacts since `Cache` needs to do some work to ensure thread safety, not to mention all the observations that would be generated.

Instead, it can be useful to batch operations to a `Cache`:

```swift
cache.performBatchUpdates { (cache) in
    cache.set(...)
    cache.set(...)
}
```

During a batch update, the closure is given a `CacheType`, a slimmed down version of `Cache`, which can be used to get and set values in the cache. The given `CacheType` isn't safe to use across multiple threads, but that also makes it faster to use. Observations are coalesced and executed after the closure.

## Author

Zach Radke, zach.radke@gmail.com

## License

Pancake is available under the MIT license. See the LICENSE file for more info.
