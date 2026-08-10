/// Cheapest / fastest marks for a trip in the current search results.
class TripHighlights {
  const TripHighlights({
    this.isCheapest = false,
    this.isFastest = false,
  });

  final bool isCheapest;
  final bool isFastest;

  bool get isDualWinner => isCheapest && isFastest;

  bool get hasAny => isCheapest || isFastest;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripHighlights &&
          isCheapest == other.isCheapest &&
          isFastest == other.isFastest;

  @override
  int get hashCode => Object.hash(isCheapest, isFastest);
}
