
import XCTest
@testable import Pancake

class ObserverTests: XCTestCase {
    var cache: Cache!

    override func setUp() {
        super.setUp()

        // GIVEN: An empty cache
        cache = Cache()
    }

    func testObserveValue() {
        // GIVEN: A cached model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // WHEN: The model is observed
        var observedModel: SimpleModel?
        let expectation = self.expectation(description: "Observer notified")
        let disposable = cached.observe { (value) in
            observedModel = value
            expectation.fulfill()
        }

        // EXPECT: A disposable to be generated and the observation to not be called
        XCTAssertNotNil(disposable)
        XCTAssertNil(observedModel)

        // WHEN: The model is updated in the cache
        let updated = SimpleModel(identifier: "A", counter: 2)
        cache.set(updated)

        // EXPECT: The observer to be notified passing the updated model
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, updated)
    }

    func testObserveMergedValue() {
        // GIVEN: A cached mergeable model inserted in the cache
        let model = MergeableModel(identifier: "A", label: nil, description: "Model A")
        cache.set(model)
        let cached = cache.cached(model)

        // WHEN: The model is observed
        var observedModel: MergeableModel?
        let expectation = self.expectation(description: "Observer notified")
        let disposable = cached.observe { (value) in
            observedModel = value
            expectation.fulfill()
        }

        // EXPECT: A disposable to be generated and the observation to not be called
        XCTAssertNotNil(disposable)
        XCTAssertNil(observedModel)

        // WHEN: The model is updated in the cache
        let updated = MergeableModel(identifier: "A", label: "New", description: nil)
        cache.set(updated)

        // EXPECT: The observer to be notified passing the merged model
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, model.merged(with: updated))
    }

    func testObserveRelatedValue() {
        // GIVEN: A chain of related models inseted in the cache
        let grandparent = RelatedModel(identifier: "A", label: nil, parent: nil)
        let parent = RelatedModel(identifier: "B", label: nil, parent: Related(grandparent))
        let child = RelatedModel(identifier: "C", label: nil, parent: Related(parent))
        cache.set(grandparent)
        cache.set(parent)
        cache.set(child)

        // WHEN: A deeply related model is observed
        let cached = cache.cached(child)
        var observedModel: RelatedModel?
        let expectation = self.expectation(description: "Observer notified")
        let disposable = cached.observe { (value) in
            observedModel = value
            expectation.fulfill()
        }

        // EXPECT: A disposable to be generated and the observation to not be called
        XCTAssertNotNil(disposable)
        XCTAssertNil(observedModel)

        // WHEN: A related model is updated in the cache
        var updated = grandparent
        updated.label = "New"
        cache.set(updated)

        // EXPECT: The observer to be notified passing the observed model (unchanged)
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, child)
    }

    func testRetrieveCachedValueInObservation() {
        // GIVEN: A cached model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // WHEN: The model is observed and the cached value is retreived
        var observedModel: SimpleModel?
        let expectation = self.expectation(description: "Observer notified")
        let disposable = cached.observe { [weak cached] (_) in
            observedModel = cached?.value
            expectation.fulfill()
        }

        // EXPECT: A disposable to be generated and the observation to not be called
        XCTAssertNotNil(disposable)
        XCTAssertNil(observedModel)

        // WHEN: The model is updated in the cache
        let updated = SimpleModel(identifier: "A", counter: 2)
        cache.set(updated)

        // EXPECT: The observer to be notified passing the updated model
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(observedModel, updated)
    }

    func testObservationLifespan() {
        // GIVEN: A model inserted into the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // WHEN: The model is observed and the disposable deallocates
        var observedModel: SimpleModel?
        autoreleasepool {
            let disposable = cached.observe { observedModel = $0 }
            XCTAssertNotNil(disposable)
        }

        // WHEN: The model is updated in the cache
        var updated = model
        updated.counter = 2
        cache.set(updated)

        // EXPECT: The model to still be in the cache but the observation to not be called

        // NOTE: This is kind of cheating, since the implementation uses barrier-async and sync, calling the getter (which is sync) forces
        // the barrier-async from the set to execute, which forces any observations to execute synchronously rather than asynchronously.
        XCTAssertEqual(updated, cache.get(model.identifier))
        XCTAssertNil(observedModel)
    }

    func testPruneUnobservedValues() {
        // GIVEN: Models inserted into the cache and one observed
        let modelA = SimpleModel(identifier: "A", counter: 1)
        let modelB = SimpleModel(identifier: "B", counter: 1)
        cache.set(modelA)
        cache.set(modelB)
        let disposable = cache.observe(modelA) { _ in }
        XCTAssertNotNil(disposable)

        // WHEN: The cache is pruned
        cache.pruneUnobservedValues()

        // EXPECT: The observed model to still be in the cache, and the unobserved model to be removed
        XCTAssertEqual(modelA, cache.get(modelA.identifier))
        XCTAssertNil(cache.get(modelB.identifier) as SimpleModel?)
    }

    func testPruneUnobservedValuesWithRelationships() {
        // GIVEN: Related models inserted into the cache and one observed
        let modelA = RelatedModel(identifier: "A", label: nil, parent: nil)
        let modelB = RelatedModel(identifier: "B", label: nil, parent: Related(modelA))
        let modelC = RelatedModel(identifier: "C", label: nil, parent: nil)
        cache.set(modelA)
        cache.set(modelB)
        cache.set(modelC)
        let disposable = cache.observe(modelB) { _ in }
        XCTAssertNotNil(disposable)

        // WHEN: The cache is pruned
        cache.pruneUnobservedValues()

        // EXPECT: The observed model and any related models to remain and any other models to be removed from the cache
        XCTAssertEqual(modelA, cache.get(modelA.identifier))
        XCTAssertEqual(modelB, cache.get(modelB.identifier))
        XCTAssertNil(cache.get(modelC.identifier) as RelatedModel?)
    }
}
