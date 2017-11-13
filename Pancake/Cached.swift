
import Foundation

/// Representation of an `Identifiable` value stored in a `Cache`
public class Cached<T> where T: Identifiable {
    /// The identifier of the value
    public let identifier: T.Identifier

    /// Retreives or sets the value in the cache
    public var value: T? {
        get {
            return cache?.get(identifier)
        }
        set {
            if let value = newValue {
                cache?.set(value)
            }
        }
    }

    /// The cache backing the value
    ///
    /// While nillable, this should typically never be nil as long as the `Cache` persists.
    public internal(set) weak var cache: Cache?

    public init(identifier: T.Identifier, cache: Cache) {
        self.identifier = identifier
        self.cache = cache
    }
}

extension Cache {
    /// Produces a `Cached` version of the given identifier
    ///
    /// - Parameter identifier: The identifier of the cached value
    /// - Returns: A `Cached` version of the value
    public func cached<T>(_ identifier: T.Identifier) -> Cached<T> {
        return Cached(identifier: identifier, cache: self)
    }

    public func cached<T>(_ value: T) -> Cached<T> {
        return Cached(identifier: value.identifier, cache: self)
    }
}

extension Related {
    /// Produces a `Cached` version of the relationship
    ///
    /// - Parameter cache: The cache to pull the related value from
    /// - Returns: A `Cached` version of the relationship
    public func cached(in cache: Cache) -> Cached<T> {
        return Cached(identifier: relatedIdentifier, cache: cache)
    }
}
