
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
        // GIVEN: A model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // GIVEN: The cached model is observed
        var observationCount = 0
        var observedModel: SimpleModel?
        let observerExpectation = self.expectation(description: "Observer notified")
        let disposable = cached.observe {
            observationCount += 1
            observedModel = $0
            observerExpectation.fulfill()
        }
        _ = disposable

        // WHEN: Batch updates are performed on the model
        let batchUpdateExpectation = self.expectation(description: "Batch update executed")
        cache.performBatchUpdates({ (cache) in
            var updated = model
            updated.counter += 1

            cache.set(updated)

            updated.counter += 1

            cache.set(updated)
        }, completion: { batchUpdateExpectation.fulfill() })

        // EXPECT: The value to be changed in the cache
        wait(for: [batchUpdateExpectation], timeout: 2)
        let expected = SimpleModel(identifier: "A", counter: 3)
        XCTAssertEqual(cache.get(model.identifier), expected)

        // EXPECT: The observer to be notified once
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, expected)
        XCTAssertEqual(observationCount, 1)
    }

    func testBatchUpdateCoalescingRelatedObservations() {
        // GIVEN: Related models inserted in the cache
        let grandparent = RelatedModel(identifier: "C", label: nil, parent: nil) // NOTE: This will be inserted in the batch updates
        let parent = RelatedModel(identifier: "A", label: nil, parent: nil)
        let child = RelatedModel(identifier: "B", label: nil, parent: Related(parent))
        cache.set(parent)
        cache.set(child)

        // GIVEN: The cached child is observed
        let cachedChild = cache.cached(child)
        var observationCount = 0
        var observedModel: RelatedModel?
        let observerExpectation = self.expectation(description: "Observer notified")
        let disposable = cachedChild.observe {
            observationCount += 1
            observedModel = $0
            observerExpectation.fulfill()
        }
        _ = disposable

        // WHEN: Batch updates are performed on a related model
        let batchUpdateExpectation = self.expectation(description: "Batch update executed")
        cache.performBatchUpdates({ (cache) in
            cache.set(grandparent)

            var updated = parent
            updated.parent = Related(grandparent)

            cache.set(updated)

            updated.label = "New"

            cache.set(updated)
        }, completion: { batchUpdateExpectation.fulfill() })

        // EXPECT: The value to be changed in the cache
        wait(for: [batchUpdateExpectation], timeout: 2)
        XCTAssertEqual(cache.get(parent.identifier), RelatedModel(identifier: "A", label: "New", parent: Related(grandparent)))
        XCTAssertEqual(cache.get(grandparent.identifier), grandparent)

        // EXPECT: The observer to be notified once
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, child)
        XCTAssertEqual(observationCount, 1)
    }

    func testRetreiveCachedValueWithinObservationDuringBatchUpdate() {
        // GIVEN: A model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // GIVEN: The cached model is observed and a cached value is retreived in the observation
        var observationCount = 0
        var observedModel: SimpleModel?
        let observerExpectation = self.expectation(description: "Observer notified")
        let disposable = cached.observe { [weak cached] (_) in
            observationCount += 1
            observedModel = cached?.value
            observerExpectation.fulfill()
        }
        _ = disposable

        // WHEN: Batch updates are performed on the model
        let batchUpdateExpectation = self.expectation(description: "Batch update executed")
        cache.performBatchUpdates({ (cache) in
            var updated = model
            updated.counter += 1

            cache.set(updated)

            updated.counter += 1

            cache.set(updated)
        }, completion: { batchUpdateExpectation.fulfill() })

        // EXPECT: The value to be changed in the cache
        wait(for: [batchUpdateExpectation], timeout: 2)
        let expected = SimpleModel(identifier: "A", counter: 3)
        XCTAssertEqual(cache.get(model.identifier), expected)

        // EXPECT: The observer to be notified once
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, expected)
        XCTAssertEqual(observationCount, 1)
    }

    func testRetreiveCachedValueDuringBatchUpdate() {
        // GIVEN: A model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // GIVEN: The cached model is observed
        var observationCount = 0
        var observedModel: SimpleModel?
        let observerExpectation = self.expectation(description: "Observer notified")
        let disposable = cached.observe { (value) in
            observationCount += 1
            observedModel = value
            observerExpectation.fulfill()
        }
        _ = disposable

        // WHEN: Batch updates are performed on the model and the value is retreived from the cache
        let batchUpdateExpectation = self.expectation(description: "Batch update executed")
        cache.performBatchUpdates({ (cache) in
            var updated = cached.value!
            updated.counter += 1

            cache.set(updated)

            updated.counter += 1

            cache.set(updated)
        }, completion: { batchUpdateExpectation.fulfill() })

        // EXPECT: The value to be changed in the cache
        wait(for: [batchUpdateExpectation], timeout: 2)
        let expected = SimpleModel(identifier: "A", counter: 3)
        XCTAssertEqual(cache.get(model.identifier), expected)

        // EXPECT: The observer to be notified once
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, expected)
        XCTAssertEqual(observationCount, 1)
    }

    func testStaleValuesDuringBatchUpdateAndUpdatedValuesAfterBatchUpdate() {
        // GIVEN: A cached model that is not inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        let cached: Cached<SimpleModel> = cache.cached(model)

        // WHEN: Batch updates are performed and the model is saved, but the cached value is accessed
        var modelDuringBatchUpdate: SimpleModel?
        var modelInCompletion: SimpleModel?
        let batchUpdateExpectation = self.expectation(description: "Batch update executed")
        cache.performBatchUpdates({ (cache) in
            cache.set(model)
            modelDuringBatchUpdate = cached.value
        }, completion: {
            modelInCompletion = cached.value
            batchUpdateExpectation.fulfill()
        })

        // EXPECT: The cached model to be stale during the batch update, and fresh in the completion
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertNil(modelDuringBatchUpdate)
        XCTAssertEqual(modelInCompletion, model)
    }
}
