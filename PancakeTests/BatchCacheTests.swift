
import XCTest
@testable import Pancake

class BatchCacheTests: XCTestCase {
    var cache: Cache!

    override func setUp() {
        super.setUp()

        // GIVEN: An empty cache
        cache = Cache()
    }

    func testBatchUpdateCoalescingObservations() {
        // GIVEN: A model inserted in the cache and observed
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)

        var observationCount = 0
        var observedModel: SimpleModel?
        let disposable = cache.observe(model) {
            observationCount += 1
            observedModel = $0
        }
        _ = disposable

        // WHEN: Batch updates are performed on the model
        cache.performBatchUpdates { (cache) in
            var updated = model
            updated.counter += 1

            cache.set(updated)

            updated.counter += 1

            cache.set(updated)
        }

        // EXPECT: The value to be changed in the cache and the observer to be notified once
        let expected = SimpleModel(identifier: "A", counter: 3)
        XCTAssertEqual(cache.get(model.identifier), expected)
        XCTAssertEqual(observedModel, expected)
        XCTAssertEqual(observationCount, 1)
    }

    func testBatchUpdateCoalescingRelatedObservations() {
        // GIVEN: Related models inserted in the cache and observed
        let grandparent = RelatedModel(identifier: "C", label: nil, parent: nil) // NOTE: This will be inserted in the batch updates
        let parent = RelatedModel(identifier: "A", label: nil, parent: nil)
        let child = RelatedModel(identifier: "B", label: nil, parent: Related(parent))
        cache.set(parent)
        cache.set(child)

        var observationCount = 0
        var observedModel: RelatedModel?
        let disposable = cache.observe(child) {
            observationCount += 1
            observedModel = $0
        }
        _ = disposable

        // WHEN: Batch updates are performed on a related model
        cache.performBatchUpdates { (cache) in
            cache.set(grandparent)

            var updated = parent
            updated.parent = Related(grandparent)

            cache.set(updated)

            updated.label = "New"

            cache.set(updated)
        }

        // EXPECT: The value to be changed in the cache and the observer to be notified once
        XCTAssertEqual(cache.get(parent.identifier), RelatedModel(identifier: "A", label: "New", parent: Related(grandparent)))
        XCTAssertEqual(cache.get(grandparent.identifier), grandparent)
        XCTAssertEqual(observedModel, child)
        XCTAssertEqual(observationCount, 1)
    }

    func testRetreiveCachedValueWithinObservationDuringBatchUpdate() {
        // GIVEN: A model inserted in the cache and uses a cached value inside the observation
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        var observationCount = 0
        var observedModel: SimpleModel?
        let disposable = cached.observe { [weak cached] (_) in
            observationCount += 1
            observedModel = cached?.value
        }
        _ = disposable

        // WHEN: Batch updates are performed on the model
        cache.performBatchUpdates { (cache) in
            var updated = model
            updated.counter += 1

            cache.set(updated)

            updated.counter += 1

            cache.set(updated)
        }

        // EXPECT: The value to be changed in the cache and the observer to be notified once
        let expected = SimpleModel(identifier: "A", counter: 3)
        XCTAssertEqual(cache.get(model.identifier), expected)
        XCTAssertEqual(observedModel, expected)
        XCTAssertEqual(observationCount, 1)
    }
}
