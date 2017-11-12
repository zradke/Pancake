
import XCTest
@testable import Pancake

class CachedTests: XCTestCase {
    var cache: Cache!

    override func setUp() {
        super.setUp()

        // GIVEN: An empty cache
        cache = Cache()
    }

    func testCachedValue() {
        // GIVEN: A model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // EXPECT: The value to match that in the cache
        XCTAssertEqual(cached.value, model)
    }

    func testCachedValueUpdated() {
        // GIVEN: A model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // WHEN: The model is updated in the cache
        var updated = model
        updated.counter = 2
        cache.set(updated)

        // EXPECT: The value to match that in the cache
        XCTAssertEqual(cached.value, updated)
    }

    func testCachedValueRemoved() {
        // GIVEN: A model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // WHEN: The cache is emptied
        cache.removeAll()

        // EXPECT: The value to match that in the cache
        XCTAssertNil(cached.value)
    }

    func testSetCachedValue() {
        // GIVEN: A model inserted in the cache
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)
        let cached = cache.cached(model)

        // WHEN: The cached value is updated
        var updated = model
        updated.counter = 2
        cached.value = updated

        // EXPECT: The value to match that in the cache
        XCTAssertEqual(cache.get(model.identifier), updated)
    }
}
