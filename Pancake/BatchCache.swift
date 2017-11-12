
import Foundation

class BatchCache {
    var cache: Cache?
    var touchedKeys: Set<CacheKey>

    init(cache: Cache) {
        self.cache = cache
        self.touchedKeys = []
    }

    func unregister() {
        cache = nil
    }
}

extension BatchCache: CacheType {
    func get<T>(_ identifier: T.Identifier) -> T? where T : Identifiable {
        let key = CacheKey(typeName: T.typeName, identifier: identifier.description)
        return cache?.valueStorage[key] as? T
    }

    func set<T>(_ value: T) where T : Identifiable {
        guard let cache = cache else { return }

        let key = CacheKey(typeName: T.typeName, identifier: value.identifier.description)
        cache.set(value, for: key)

        touchedKeys.insert(key)
    }

    func set<T>(_ value: T) where T : Identifiable, T : Mergeable {
        guard let cache = cache else { return }

        let key = CacheKey(typeName: T.typeName, identifier: value.identifier.description)
        cache.merge(value, for: key)

        touchedKeys.insert(key)
    }

    func removeAll() {
        cache?.removeAll()
    }
}

extension Cache {
    /// Provides a batch interface for manipulating the receiver
    ///
    /// This is mostly useful for batch inserting as a way to reduce duplicated observer notifications and potentially save performance by
    /// only acquiring the receiver's lock once over many operations. The closure is passed an abstract `CacheType` with a reduced
    /// interface to prevent cycles of batch updates or observations on the abstract cache.
    ///
    /// - Note: The given cache is not safe to use from multiple threads. Do not attempt to let the cache escape from the given closure. It
    ///   will cease to work once the closure has finished executing
    ///
    /// - Parameter action: A closure given an abstract `CacheType` on which to perform batched updates
    public func performBatchUpdates(_ action: @escaping (CacheType) -> Void) {
        queue.async(flags: .barrier) {
            let batchCache = BatchCache(cache: self)
            action(batchCache)
            batchCache.unregister()

            for (observer, value) in self.touchedValuesForObservers(for: batchCache.touchedKeys) {
                observer.observation(value)
            }
        }
    }
}
