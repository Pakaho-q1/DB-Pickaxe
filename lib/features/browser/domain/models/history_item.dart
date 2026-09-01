class HistoryItem {
  final String id;
  final String title;
  final String url;
  final DateTime visitedAt;
  final int visitCount;

  const HistoryItem({
    required this.id,
    required this.title,
    required this.url,
    required this.visitedAt,
    this.visitCount = 1,
  });

  HistoryItem copyWith({
    String? title,
    DateTime? visitedAt,
    int? visitCount,
  }) {
    return HistoryItem(
      id: id,
      title: title ?? this.title,
      url: url,
      visitedAt: visitedAt ?? this.visitedAt,
      visitCount: visitCount ?? this.visitCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'visitedAt': visitedAt.toIso8601String(),
      'visitCount': visitCount,
    };
  }

  factory HistoryItem.fromMap(Map<dynamic, dynamic> map) {
    return HistoryItem(
      id: map['id'] as String,
      title: map['title'] as String,
      url: map['url'] as String,
      visitedAt: DateTime.parse(map['visitedAt'] as String),
      visitCount: map['visitCount'] as int? ?? 1,
    );
  }
}
