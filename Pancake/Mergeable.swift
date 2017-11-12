
import Foundation

/// Conformers can be merged with other values of the same type
///
/// The `Cache` will automatically try and merge `Identifiable` values that conform to this protocol when setting them.
public protocol Mergeable {
    /// Produces a value that merges attributes from the receiver with those of another value.
    ///
    /// - Parameter other: Another value of the same type
    /// - Returns: A value that merges attributes of the receiver with those of the given value
    func merged(with other: Self) -> Self

    /// Merges the reciever in place with a given value
    ///
    /// - Parameter other: Another value of the same type
    mutating func merge(with other: Self)
}

extension Mergeable {
    public mutating func merge(with other: Self) {
        self = merged(with: other)
    }
}
