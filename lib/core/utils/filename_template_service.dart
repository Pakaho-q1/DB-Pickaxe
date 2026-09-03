class FilenameTemplateService {
  /// Default filename template: `[Title] - [Filename]` or `[Domain]_[Title]_[Resolution].[ext]`
  static const String defaultTemplate = '{title} - {filename}';

  /// Renders a template with provided media metadata.
  static String render({
    required String template,
    String? title,
    String? originalFilename,
    String? domain,
    String? resolution,
    String? extension,
    int? index,
    DateTime? date,
  }) {
    String result = template.isEmpty ? defaultTemplate : template;
    final now = date ?? DateTime.now();

    final cleanTitle = _sanitize(title ?? '');
    final cleanOriginal = _sanitize(originalFilename ?? 'media');
    final cleanDomain = _sanitize(domain ?? '');
    final cleanRes = _sanitize(resolution ?? '');
    String cleanExt = (extension ?? '').trim();
    if (cleanExt.isNotEmpty && !cleanExt.startsWith('.')) {
      cleanExt = '.$cleanExt';
    }

    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final indexStr = index != null ? index.toString().padLeft(2, '0') : '';

    result = result.replaceAll('{title}', cleanTitle.isNotEmpty ? cleanTitle : cleanOriginal);
    result = result.replaceAll('{filename}', cleanOriginal);
    result = result.replaceAll('{domain}', cleanDomain);
    result = result.replaceAll('{resolution}', cleanRes);
    result = result.replaceAll('{date}', dateStr);
    result = result.replaceAll('{index}', indexStr);
    result = result.replaceAll('{ext}', cleanExt.replaceAll('.', ''));

    // Clean up empty separator residues like "-  -" or "__" or leading/trailing dashes
    result = result.replaceAll(RegExp(r'\s+-\s+-\s+'), ' - ');
    result = result.replaceAll(RegExp(r'_+'), '_');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    result = result.trim();

    if (result.endsWith('-') || result.endsWith('_')) {
      result = result.substring(0, result.length - 1).trim();
    }

    if (result.isEmpty) {
      result = cleanOriginal.isNotEmpty ? cleanOriginal : 'download_${now.millisecondsSinceEpoch}';
    }

    if (cleanExt.isNotEmpty && !result.toLowerCase().endsWith(cleanExt.toLowerCase())) {
      result = '$result$cleanExt';
    }

    return _sanitize(result);
  }

  /// Generates a subfolder name based on website domain and page title/album
  static String generateSubfolder({
    String? domain,
    String? pageTitle,
    bool autoCreateSubfolders = true,
  }) {
    if (!autoCreateSubfolders) return '';
    final d = _sanitize(domain ?? '').trim();
    final t = _sanitize(pageTitle ?? '').trim();

    if (d.isNotEmpty && t.isNotEmpty) {
      return '$d/$t';
    } else if (d.isNotEmpty) {
      return d;
    } else if (t.isNotEmpty) {
      return t;
    }
    return '';
  }

  static String _sanitize(String input) {
    return input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\r\n\t]'), ' ')
        .trim();
  }
}
