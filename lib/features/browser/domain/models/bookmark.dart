class Bookmark {
  final String id;
  final String title;
  final String url;
  final String? faviconUrl;
  final String folder;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.title,
    required this.url,
    this.faviconUrl,
    this.folder = 'Default',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'faviconUrl': faviconUrl,
      'folder': folder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<dynamic, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      title: map['title'] as String,
      url: map['url'] as String,
      faviconUrl: map['faviconUrl'] as String?,
      folder: map['folder'] as String? ?? 'Default',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
