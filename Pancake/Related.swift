
import Foundation

/// Representation of a relationship to a cacheable value
///
/// - SeeAlso: `Identifiable`
public struct Related<T>: Codable where T: Identifiable {
    /// The identifier of the related value
    public let relatedIdentifier: T.Identifier

    public init(_ relatedIdentifier: T.Identifier) {
        self.relatedIdentifier = relatedIdentifier
    }

    public init(_ value: T) {
        self.relatedIdentifier = value.identifier
    }

    public var cacheKey: CacheKey {
        return CacheKey(typeName: T.typeName, identifier: relatedIdentifier.description)
    }
}

extension Related: Hashable {
    public var hashValue: Int { return relatedIdentifier.hashValue }

    public static func ==(lhs: Related, rhs: Related) -> Bool {
        return lhs.relatedIdentifier == rhs.relatedIdentifier
    }
}
