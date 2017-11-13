
import Foundation

/// A type agnostic key used by the `Cache` to identify values
public struct CacheKey: Codable {
    public let typeName: String
    public let identifier: String
}

extension CacheKey: Hashable {
    public var hashValue: Int { return typeName.hashValue ^ identifier.hashValue }

    public static func ==(lhs: CacheKey, rhs: CacheKey) -> Bool {
        return lhs.typeName == rhs.typeName && lhs.identifier == rhs.identifier
    }
}
