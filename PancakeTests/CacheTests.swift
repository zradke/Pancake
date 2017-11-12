
import XCTest
@testable import Pancake

class CacheTests: XCTestCase {
    var cache: Cache!

    override func setUp() {
        super.setUp()

        // GIVEN: An empty cache
        cache = Cache()
    }

    func testSetBasic() {
        // GIVEN: A non-mergeable model
        let model = SimpleModel(identifier: "A", counter: 1)

        // WHEN: The model is inserted into the cache
        cache.set(model)

        // EXPECT: The model to be retreivable from the cache
        let retreived: SimpleModel? = cache.get(model.identifier)
        XCTAssertEqual(model, retreived)
    }

    func testSetMergeable() {
        // GIVEN: A mergeable model
        let model = MergeableModel(identifier: "A", label: nil, description: "Model A")

        // WHEN: The model is inserted into the cache
        cache.set(model)

        // EXPECT: The model to be retreivable from the cache
        var retreived: MergeableModel? = cache.get(model.identifier)
        XCTAssertEqual(model, retreived)

        // GIVEN: A model with the same identifier but different properties
        let updated = MergeableModel(identifier: "A", label: "New", description: nil)

        // WHEN: The updated model is inserted into the cache
        cache.set(updated)

        // EXPECT: A merged copy of the two models to be retreivable from the cache
        retreived = cache.get(model.identifier)
        XCTAssertEqual(model.merged(with: updated), retreived)
    }

    func testGetUnknown() {
        // WHEN: Retreiving a model identifier that was not inserted in the cache
        let retreived: SimpleModel? = cache.get("A")

        // EXPECT: The model to be nil
        XCTAssertNil(retreived)
    }

    func testRemoveAll() {
        // GIVEN: A cache with a model inserted
        let model = SimpleModel(identifier: "A", counter: 1)
        cache.set(model)

        // WHEN: The cache is emptied
        cache.removeAll()

        // EXPECT: The model to not be retreivable from the cache
        let retreived: SimpleModel? = cache.get(model.identifier)
        XCTAssertNil(retreived)
    }
}
