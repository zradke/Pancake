
import XCTest
@testable import Pancake

class RelatedTests: XCTestCase {
    func testInitWithIdentifier() {
        // GIVEN: A relatable model
        let model = RelatedModel(identifier: "A", label: nil, parent: nil)

        // WHEN: A related value is created with the identifier
        let related: Related<RelatedModel> = Related(model.identifier)

        // EXPECT: The related identifier to match the model
        XCTAssertEqual(related.relatedIdentifier, model.identifier)
    }

    func testInitWithModel() {
        // GIVEN: A relatable model
        let model = RelatedModel(identifier: "A", label: nil, parent: nil)

        // WHEN: A related value is created with the model
        let related = Related(model)

        // EXPECT: The related identifier to match the model
        XCTAssertEqual(related.relatedIdentifier, model.identifier)
    }

    func testEncodeDecode() {
        // GIVEN: A codable model with a relationship
        let parent = RelatedModel(identifier: "A", label: nil, parent: nil)
        let child = RelatedModel(identifier: "B", label: nil, parent: Related(parent))

        // WHEN: The child is encoded and the data is decoded
        let data = try! JSONEncoder().encode(child)
        let decoded = try! JSONDecoder().decode(RelatedModel.self, from: data)

        // EXPECT: The decoded model to match
        XCTAssertEqual(child, decoded)

        // EXPECT: The decoded relationship to still exist
        XCTAssertEqual(child.parent, Related(parent))
    }
}
