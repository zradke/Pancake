
import Foundation
@testable import Pancake

struct SimpleModel: Identifiable, Equatable {
    var identifier: String
    var counter: Int

    static func ==(lhs: SimpleModel, rhs: SimpleModel) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.counter == rhs.counter
    }
}

struct MergeableModel: Identifiable, Mergeable, Equatable {
    var identifier: String
    var label: String?
    var description: String?

    func merged(with other: MergeableModel) -> MergeableModel {
        var copy = self

        if let otherLabel = other.label {
            copy.label = otherLabel
        }

        if let otherDescription = other.description {
            copy.description = otherDescription
        }

        return copy
    }

    static func ==(lhs: MergeableModel, rhs: MergeableModel) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.label == rhs.label && lhs.description == rhs.description
    }
}

struct RelatedModel: Identifiable, HasCachedRelationships, Equatable, Codable {
    var identifier: String
    var label: String?
    var parent: Related<RelatedModel>?

    var relatedCacheKeys: Set<CacheKey> {
        var relatedKeys: Set<CacheKey> = []
        if let parent = parent { relatedKeys.insert(parent.cacheKey) }
        return relatedKeys
    }

    static func ==(lhs: RelatedModel, rhs: RelatedModel) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.label == rhs.label && lhs.parent == rhs.parent
    }
}
