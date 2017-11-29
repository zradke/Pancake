
import Foundation

class BatchCache {
    var valueStorage: [CacheKey: Any]
    var modifiedStorage: [CacheKey: Any]

    init(_ cache: Cache) {
        self.valueStorage = cache.valueStorage
        self.modifiedStorage = [:]
    }
}

extension BatchCache: CacheType {
    func get<T>(_ identifier: T.Identifier) -> T? where T : Identifiable {
        let key = CacheKey(typeName: T.typeName, identifier: identifier.description)
        return modifiedStorage[key] as? T ?? valueStorage[key] as? T
    }

    func set<T>(_ value: T) where T : Identifiable {
        let key = CacheKey(typeName: T.typeName, identifier: value.identifier.description)
        modifiedStorage[key] = value
    }

    func set<T>(_ value: T) where T : Identifiable, T : Mergeable {
        let key = CacheKey(typeName: T.typeName, identifier: value.identifier.description)

        if let existingValue: T = get(value.identifier) {
            modifiedStorage[key] = existingValue.merged(with: value)
        } else {
            modifiedStorage[key] = value
        }
    }
}

extension Cache {
    /// Provides a batch interface for manipulating the receiver
    ///
    /// This is mostly useful for batch inserting as a way to reduce duplicated observer notifications and potentially save performance by
    /// only acquiring the receiver's lock once over many operations. The closure is passed an abstract `CacheType` with a reduced
    /// interface to prevent cycles of batch updates or observations on the abstract cache.
    ///
    /// - Note: The given cache is not safe to use from multiple threads. Do not attempt to let the cache escape from the given closure.
    ///
    /// - Warning: It is possible for data loss to occur during a batch update if the same values are modified in both the batch update and
    ///   the `Cache` while the action is being executed. In such a case the batch cache's value will be taken as canonical.
    ///
    /// - Parameter action: A closure given an abstract `CacheType` on which to perform batched updates
    public func performBatchUpdates(_ action: @escaping (CacheType) -> Void) {
        // On the workQueue to ensure the batch cache has the latest values, but async to prevent deadlock. Barrier is
        // unnecessary since the data is not mutated at this point
        workQueue.async {
            let batchCache = BatchCache(self)
            self.execute(action, with: batchCache)
        }
    }

    private func execute(_ action: @escaping (CacheType) -> Void, with batchCache: BatchCache) {
        observerQueue.async { // Must not be on the workQueue queue to prevent deadlocks
            action(batchCache)
            self.mergeAndNotify(batchCache)
        }
    }

    private func mergeAndNotify(_ batchCache: BatchCache) {
        workQueue.async(flags: .barrier) {
            // Bake the modifiedStorage to prevent threading mutations if the batch cache is (improperly) allowed to move across threads
            let batchStorage = batchCache.modifiedStorage

            // There is unfortunately no way to replay the actions of the batch cache (which would be ideal to prevent the data loss
            // mentioned in the warning), so instead the batch storage is directly merged with the valueStorage, with the batch storage
            // values taking precedence.
            self.valueStorage.merge(batchStorage, uniquingKeysWith: { (_, new) in return new })

            let touchedValuesForObservers = self.touchedValuesForObservers(for: Set(batchStorage.keys))
            self.observerQueue.async {
                for (observer, value) in touchedValuesForObservers {
                    observer.observation(value)
                }
            }
        }
    }
}
