class Book {
  final int id, totalPages, currentPage;
  final String label, timeStamp;

  Book({
    required this.timeStamp,
    required this.currentPage,
    required this.totalPages,
    required this.id,
    required this.label,
  });

  double get progress {
    if (totalPages > 0) {
      return currentPage / totalPages;
    }
    return 0.0;
  }
}
