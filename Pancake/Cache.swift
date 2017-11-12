
import Foundation

/// Conformers are flat caches that can store and retreive arbitrary `Identifiable` values
///
/// - SeeAlso: `Cache`
public protocol CacheType {
    /// Fetches an arbitrary `Identifiable` typed value from the receiver
    ///
    /// - Parameter identifier: The identifier of the desired value
    /// - Returns: A value of the desired type matching the identifier if it exists in the receiver
    func get<T>(_ identifier: T.Identifier) -> T? where T: Identifiable

    /// Sets an arbitrary `Identifiable` value in the receiver
    ///
    /// - Parameter value: The `Identifiable` value
    func set<T>(_ value: T) where T: Identifiable

    /// Sets or merges an arbitrary `Identifiable` and `Mergeable` value in the receiver
    ///
    /// If a value with the same identifier exists in the receiver, setting another value with the same identifier will merge the two
    /// instead of replacing it.
    ///
    /// - Parameter value: An `Identifiable` and `Mergeable` value
    func set<T>(_ value: T) where T: Identifiable, T: Mergeable

    /// Removes all values from the receiver
    func removeAll()
}

/// A flat cache that can store, retreive, and observe arbitrary `Identifiable` values
///
/// This class is a concrete implementation of the `CacheType` protocol with enhancements to allow observation of cached values as well as
/// batch updates which coallesce observation notifications. Instances are thread safe when reading or writing values.
///
/// - Note: Cached values should typically be value types to ensure that observations are properly distributed and values are not changed
///   on multiple threads
///
/// - SeeAlso: `Identifiable`
public class Cache {
    let queue: DispatchQueue
    var valueStorage: [CacheKey: Any]
    var relationshipStorage: [CacheKey: Set<CacheKey>]
    let observerStorage: NSHashTable<Observer>

    public init() {
        self.queue = DispatchQueue(label: "com.zachradke.pancake.cache.queue", attributes: .concurrent)
        self.valueStorage = [:]
        self.relationshipStorage = [:]
        self.observerStorage = .weakObjects()
    }

    func set(_ value: Any, for key: CacheKey) {
        valueStorage[key] = value

        if let value = value as? HasCachedRelationships {
            relationshipStorage[key] = value.relatedCacheKeys
        }
    }

    func merge<T>(_ value: T, for key: CacheKey) where T: Mergeable {
        if let existingValue = valueStorage[key] as? T {
            set(existingValue.merged(with: value), for: key)
        } else {
            set(value, for: key)
        }
    }

    func touchedValuesForObservers(for keys: Set<CacheKey>) -> [Observer: Any] {
        var touchedKeys: Set<CacheKey> = keys

        func accumulateTouchedKeys(for currentKey: CacheKey, touchedKeys: inout Set<CacheKey>) {
            let directlyRelatedKeys = relationshipStorage
                .filter { $0.value.contains(currentKey) }
                .keys
            let untouchedKeys = Set(directlyRelatedKeys).subtracting(touchedKeys)
            touchedKeys.formUnion(untouchedKeys)

            for key in untouchedKeys {
                accumulateTouchedKeys(for: key, touchedKeys: &touchedKeys)
            }
        }

        for key in keys {
            accumulateTouchedKeys(for: key, touchedKeys: &touchedKeys)
        }

        let pairs: [(Observer, Any)] = observerStorage
            .allObjects
            .filter { touchedKeys.contains($0.key) }
            .flatMap {
                if let value = valueStorage[$0.key] {
                    return ($0, value)
                } else {
                    return nil
                }
            }

        return Dictionary(uniqueKeysWithValues: pairs)
    }
}

extension Cache: CacheType {
    public func get<T>(_ identifier: T.Identifier) -> T? where T : Identifiable {
        let key = CacheKey(typeName: T.typeName, identifier: identifier.description)
        var value: T?

        queue.sync {
            value = self.valueStorage[key] as? T
        }

        return value
    }

    public func set<T>(_ value: T) where T : Identifiable {
        queue.async(flags: .barrier) {
            let key = CacheKey(typeName: T.typeName, identifier: value.identifier.description)
            self.set(value, for: key)
            let touchedValuesForObservers = self.touchedValuesForObservers(for: [key])

            for (observer, value) in touchedValuesForObservers {
                observer.observation(value)
            }
        }
    }

    public func set<T>(_ value: T) where T : Identifiable, T : Mergeable {
        queue.async(flags: .barrier) {
            let key = CacheKey(typeName: T.typeName, identifier: value.identifier.description)
            self.merge(value, for: key)
            let touchedValuesForObservers = self.touchedValuesForObservers(for: [key])

            for (observer, value) in touchedValuesForObservers {
                observer.observation(value)
            }

        }
    }

    public func removeAll() {
        queue.async(flags: .barrier) {
            self.valueStorage.removeAll()
            self.relationshipStorage.removeAll()
        }
    }
}
