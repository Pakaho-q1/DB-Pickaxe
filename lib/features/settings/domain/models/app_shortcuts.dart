class AppShortcuts {
  final String closeTab;
  final String newTab;
  final String closeOtherTabs;
  final String detectMedia;
  final String toggleMediaDeck;
  final String focusUrlBar;
  final String downloadHoverMedia;

  const AppShortcuts({
    this.closeTab = 'Ctrl+W',
    this.newTab = 'Ctrl+T',
    this.closeOtherTabs = 'Ctrl+Shift+W',
    this.detectMedia = 'Ctrl+R',
    this.toggleMediaDeck = 'Ctrl+B',
    this.focusUrlBar = 'Ctrl+L',
    this.downloadHoverMedia = 'Shift+D',
  });

  AppShortcuts copyWith({
    String? closeTab,
    String? newTab,
    String? closeOtherTabs,
    String? detectMedia,
    String? toggleMediaDeck,
    String? focusUrlBar,
    String? downloadHoverMedia,
  }) {
    return AppShortcuts(
      closeTab: closeTab ?? this.closeTab,
      newTab: newTab ?? this.newTab,
      closeOtherTabs: closeOtherTabs ?? this.closeOtherTabs,
      detectMedia: detectMedia ?? this.detectMedia,
      toggleMediaDeck: toggleMediaDeck ?? this.toggleMediaDeck,
      focusUrlBar: focusUrlBar ?? this.focusUrlBar,
      downloadHoverMedia: downloadHoverMedia ?? this.downloadHoverMedia,
    );
  }

  Map<String, dynamic> toMap() => {
        'closeTab': closeTab,
        'newTab': newTab,
        'closeOtherTabs': closeOtherTabs,
        'detectMedia': detectMedia,
        'toggleMediaDeck': toggleMediaDeck,
        'focusUrlBar': focusUrlBar,
        'downloadHoverMedia': downloadHoverMedia,
      };

  factory AppShortcuts.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const AppShortcuts();
    return AppShortcuts(
      closeTab: map['closeTab'] as String? ?? 'Ctrl+W',
      newTab: map['newTab'] as String? ?? 'Ctrl+T',
      closeOtherTabs: map['closeOtherTabs'] as String? ?? 'Ctrl+Shift+W',
      detectMedia: map['detectMedia'] as String? ?? 'Ctrl+R',
      toggleMediaDeck: map['toggleMediaDeck'] as String? ?? 'Ctrl+B',
      focusUrlBar: map['focusUrlBar'] as String? ?? 'Ctrl+L',
      downloadHoverMedia: map['downloadHoverMedia'] as String? ?? 'Shift+D',
    );
  }
}
