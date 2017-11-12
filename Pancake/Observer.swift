
import Foundation

class Observer {
    let key: CacheKey
    let observation: (Any) -> Void

    init(_ key: CacheKey, observation: @escaping (Any) -> Void) {
        self.key = key
        self.observation = observation
    }
}

extension Observer: Hashable {
    var hashValue: Int { return ObjectIdentifier(self).hashValue }

    static func ==(lhs: Observer, rhs: Observer) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension Cache {
    /// An arbitrary object that, when deallocated, will end an observation
    public typealias Disposable = AnyObject

    /// Adds an observation on a given identified value in the receiver
    ///
    /// The observation is executed whenever the value, or any related value, is modified in the receiver. No guarantee is made on what
    /// thread the observation will be called. In order to keep observing the value, the returned `Disposable` token must be retained. As
    /// soon as it is disposed of, the observation ends.
    ///
    /// If the observed value conforms to `HasCachedRelationships`, those relationships are used to drive indirect observations. For example,
    /// consider an `Author` type and a `Book` type, both which conform to `HasCachedRelationships`:
    ///
    ///     struct Author: Identifiable, HasCachedRelationships {
    ///         var identifier: String
    ///         var name: String
    ///         var works: [Related<Book>]
    ///
    ///         var relatedCacheKeys: Set<CacheKey> { return Set(works.map({ $0.cacheKey })) }
    ///     }
    ///
    ///     struct Book: Identifiable, HasCachedRelationships {
    ///         var identifier: String
    ///         var title: String
    ///         var author: Related<Author>
    ///
    ///         var relatedCacheKeys: Set<CacheKey> { return [author.cacheKey] }
    ///     }
    ///
    /// If there was a novel, "The Cuckoo's Calling", written by an author, "Robert Galbraith", but that author then changed their name to
    /// "JK Rowling", an observer on "The Cuckoo's Calling" would be notified when the author is changed in the cache. This works on an
    /// indefinitely deep nesting of related objects.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the value to observe
    ///   - observation: A closure that is executed whenever the value, or a related value, is modified in the cache
    /// - Returns: A `Disposable` token that must be retained to continue observing the value
    ///
    /// - SeeAlso: `HasCachedRelationships`
    public func observe<T>(_ identifier: T.Identifier, observation: @escaping (T) -> Void) -> Disposable where T: Identifiable {
        let key = CacheKey(typeName: T.typeName, identifier: identifier.description)
        let observer = Observer(key) { (value) in
            if let value = value as? T { observation(value) }
        }

        queue.async(flags: .barrier) {
            self.observerStorage.add(observer)
        }

        return observer
    }

    /// Adds an observation of a given value in the receiver
    ///
    /// The observation is executed whenever the value, or any related value, is modified in the receiver. No guarantee is made on what
    /// thread the observation will be called. In order to keep observing the value, the returned `Disposable` token must be retained. As
    /// soon as it is disposed of, the observation ends.
    ///
    /// If the observed value conforms to `HasCachedRelationships`, those relationships are used to drive indirect observations. For example,
    /// consider an `Author` type and a `Book` type, both which conform to `HasCachedRelationships`:
    ///
    ///     struct Author: Identifiable, HasCachedRelationships {
    ///         var identifier: String
    ///         var name: String
    ///         var works: [Related<Book>]
    ///
    ///         var relatedCacheKeys: Set<CacheKey> { return Set(works.map({ $0.cacheKey })) }
    ///     }
    ///
    ///     struct Book: Identifiable, HasCachedRelationships {
    ///         var identifier: String
    ///         var title: String
    ///         var author: Related<Author>
    ///
    ///         var relatedCacheKeys: Set<CacheKey> { return [author.cacheKey] }
    ///     }
    ///
    /// If there was a novel, "The Cuckoo's Calling", written by an author, "Robert Galbraith", but that author then changed their name to
    /// "JK Rowling", an observer on "The Cuckoo's Calling" would be notified when the author is changed in the cache. This works on an
    /// indefinitely deep nesting of related objects.
    ///
    /// - Parameters:
    ///   - value: The value to observe
    ///   - observation: A closure that is executed whenever the value, or a related value, is modified in the cache
    /// - Returns: A `Disposable` token that must be retained to continue observing the value
    ///
    /// - SeeAlso: `Cache.observe(_:,observation:)`
    public func observe<T>(_ value: T, observation: @escaping (T) -> Void) -> Disposable where T: Identifiable {
        return observe(value.identifier, observation: observation)
    }

    /// Removes any values from the receiver that are not directly or indirectly observed
    public func pruneUnobservedValues() {
        queue.async(flags: .barrier) {
            let directlyObservedKeys = Set(self.observerStorage.allObjects.map { $0.key })
            var observedKeys = directlyObservedKeys

            for key in directlyObservedKeys {
                if let relatedKeys = self.relationshipStorage[key] {
                    observedKeys.formUnion(relatedKeys)
                }
            }

            self.valueStorage = self.valueStorage.filter { observedKeys.contains($0.key) }
        }
    }
}


extension Cached {
    /// Adds an observer to the cached value
    ///
    /// The observation is executed whenever the value, or any related value, is modified in the receiver. No guarantee is made on what
    /// thread the observation will be called. In order to keep observing the value, the returned `Disposable` token must be retained. As
    /// soon as it is disposed of, the observation ends.
    ///
    /// If the observed value conforms to `HasCachedRelationships`, those relationships are used to drive indirect observations. For
    /// example, consider an `Author` type and a `Book` type, both which conform to `HasCachedRelationships`:
    ///
    ///     struct Author: Identifiable, HasCachedRelationships {
    ///         var identifier: String
    ///         var name: String
    ///         var works: [Related<Book>]
    ///
    ///         var relatedCacheKeys: Set<CacheKey> { return Set(works.map({ $0.cacheKey })) }
    ///     }
    ///
    ///     struct Book: Identifiable, HasCachedRelationships {
    ///         var identifier: String
    ///         var title: String
    ///         var author: Related<Author>
    ///
    ///         var relatedCacheKeys: Set<CacheKey> { return [author.cacheKey] }
    ///     }
    ///
    /// If there was a novel, "The Cuckoo's Calling", written by an author, "Robert Galbraith", but that author then changed their name to
    /// "JK Rowling", an observer on "The Cuckoo's Calling" would be notified when the author is changed in the cache. This works on an
    /// indefinitely deep nesting of related objects.
    ///
    /// - Parameter observation: A closure that is executed whenever the value, or a related value, is modfied in the cache
    /// - Returns: A `Cache.Disposable` token that must be retained to continue observing the values
    ///
    /// - SeeAlso: `HasCachedRelationships`, `Cache.observe(_:,observation:)`
    public func observe(_ observation: @escaping (T) -> Void) -> Cache.Disposable? {
        return cache?.observe(identifier, observation: observation)
    }
}
