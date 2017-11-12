
import Foundation

/// Conformers are identifiable
///
/// This is the minimum requirement for values inserted into a `Cache`. They should be representable as a `CacheKey`
///
/// - SeeAlso: `Cache`
public protocol Identifiable {
    /// The type of value identifiers
    ///
    /// This type should be representable as a `String` in order to convert properly into a `CacheKey`
    associatedtype Identifier: CustomStringConvertible, Hashable

    /// The identifier of the value
    var identifier: Identifier { get }
}

extension Identifiable {
    static var typeName: String {
        return String(describing: self)
    }
}
