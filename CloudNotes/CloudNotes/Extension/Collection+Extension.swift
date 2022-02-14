extension Collection {
  subscript(safe index: Index) -> Element? {
    let validIndices = startIndex..<endIndex
    return validIndices ~= index ? self[index] : nil
  }
}
