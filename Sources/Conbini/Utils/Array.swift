internal extension Array {
    /// Removes and returns the first element of the collection.
    /// - returns: The first element of the collection if the collection is not empty; otherwise, nil
    /// - complexity: O(1)
    mutating func popFirst() -> Element? {
        guard !self.isEmpty else { return nil }
        return self.removeFirst()
    }
}
