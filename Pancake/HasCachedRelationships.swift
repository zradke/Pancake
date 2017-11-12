
import Foundation

/// Conformers indicate that they have one or more relationships to cached values
///
/// - SeeAlso: `Related`, `CacheKey`, `Cache`
public protocol HasCachedRelationships {
    /// Returns a set of `CacheKey` values representing related values
    var relatedCacheKeys: Set<CacheKey> { get }
}
