import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../sniffer/domain/models/detected_media.dart';
import '../providers/download_queue_provider.dart';

class DirectDownloadDialog extends ConsumerStatefulWidget {
  const DirectDownloadDialog({super.key});

  @override
  ConsumerState<DirectDownloadDialog> createState() => _DirectDownloadDialogState();
}

class _DirectDownloadDialogState extends ConsumerState<DirectDownloadDialog> {
  final _urlController = TextEditingController();
  final _filenameController = TextEditingController();
  MediaType _selectedType = MediaType.video;

  @override
  void dispose() {
    _urlController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  void _onUrlChanged(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.contains('.m3u8')) {
      setState(() => _selectedType = MediaType.stream);
    } else if (lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.webm')) {
      setState(() => _selectedType = MediaType.video);
    } else if (lower.endsWith('.jpg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
      setState(() => _selectedType = MediaType.image);
    } else if (lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.wav')) {
      setState(() => _selectedType = MediaType.audio);
    }

    if (_filenameController.text.isEmpty && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url.trim());
        final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        if (last.isNotEmpty) {
          _filenameController.text = last.split('?').first;
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_link, color: AppTheme.accentCyan, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Direct URL Downloader',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Download Link (URL / M3U8 Stream)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              onChanged: _onUrlChanged,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'https://example.com/video.mp4 or master.m3u8...',
                prefixIcon: Icon(Icons.link, size: 16, color: AppTheme.darkTextSecondary),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Custom Filename (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _filenameController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'my_download.mp4',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Media Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<MediaType>(
                        initialValue: _selectedType,
                        dropdownColor: AppTheme.darkSurface,
                        decoration: const InputDecoration(isDense: true),
                        items: const [
                          DropdownMenuItem(value: MediaType.video, child: Text('Video (.mp4)')),
                          DropdownMenuItem(value: MediaType.stream, child: Text('HLS Stream (.m3u8)')),
                          DropdownMenuItem(value: MediaType.image, child: Text('Image')),
                          DropdownMenuItem(value: MediaType.audio, child: Text('Audio')),
                          DropdownMenuItem(value: MediaType.other, child: Text('File / Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Start Download', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final url = _urlController.text.trim();
                    if (url.isEmpty) return;

                    var name = _filenameController.text.trim();
                    final ext = _selectedType == MediaType.stream || _selectedType == MediaType.video
                        ? '.mp4'
                        : _selectedType == MediaType.image
                            ? '.jpg'
                            : _selectedType == MediaType.audio
                                ? '.mp3'
                                : '';

                    if (name.isEmpty) {
                      name = 'direct_download_${DateTime.now().millisecondsSinceEpoch}$ext';
                    } else if (ext.isNotEmpty && !name.toLowerCase().endsWith(ext)) {
                      name = '$name$ext';
                    }

                    final media = DetectedMedia(
                      id: const Uuid().v4(),
                      url: url,
                      pageUrl: url,
                      filename: name,
                      mediaType: _selectedType,
                      extension: ext,
                      detectedAt: DateTime.now(),
                    );

                    ref.read(downloadQueueProvider.notifier).addMediaToQueue(media);
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to download queue: $name'),
                        backgroundColor: AppTheme.accentGreen,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
