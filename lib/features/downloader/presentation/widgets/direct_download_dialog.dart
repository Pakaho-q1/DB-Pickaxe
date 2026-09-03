import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/clipboard_watcher_service.dart';
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
  void initState() {
    super.initState();
    ClipboardWatcherService.startWatching();
  }

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
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 580,
        height: 480,
        padding: const EdgeInsets.all(18),
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TabBar(
                    isScrollable: true,
                    indicatorColor: AppTheme.accentCyan,
                    labelColor: AppTheme.accentCyan,
                    unselectedLabelColor: AppTheme.darkTextSecondary,
                    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(icon: Icon(Icons.add_link, size: 16), text: 'Direct Link Download'),
                      Tab(icon: Icon(Icons.content_paste_search, size: 16), text: 'Clipboard Link Watcher'),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDirectTab(),
                    _buildClipboardTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  const Text('Filename (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _filenameController,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'video.mp4, image.png...',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Media Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkTextPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<MediaType>(
                    initialValue: _selectedType,
                    dropdownColor: AppTheme.darkSurface,
                    decoration: const InputDecoration(isDense: true),
                    items: const [
                      DropdownMenuItem(value: MediaType.video, child: Text('Video (MP4)')),
                      DropdownMenuItem(value: MediaType.stream, child: Text('HLS Stream (M3U8)')),
                      DropdownMenuItem(value: MediaType.image, child: Text('Image')),
                      DropdownMenuItem(value: MediaType.audio, child: Text('Audio (MP3)')),
                      DropdownMenuItem(value: MediaType.other, child: Text('File / Archive')),
                    ],
                    onChanged: (type) {
                      if (type != null) setState(() => _selectedType = type);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
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
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Start Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () {
                final url = _urlController.text.trim();
                if (url.isEmpty) return;

                var filename = _filenameController.text.trim();
                if (filename.isEmpty) {
                  filename = 'download_${DateTime.now().millisecondsSinceEpoch}.${_selectedType == MediaType.stream ? 'mp4' : 'dat'}';
                }

                final detected = DetectedMedia(
                  id: const Uuid().v4(),
                  url: url,
                  pageUrl: '',
                  filename: filename,
                  mediaType: _selectedType,
                  extension: filename.contains('.') ? '.${filename.split('.').last}' : '.dat',
                  detectedAt: DateTime.now(),
                );

                ref.read(downloadQueueProvider.notifier).addMediaToQueue(detected);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to download queue: $filename')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClipboardTab() {
    return StreamBuilder<List<String>>(
      stream: ClipboardWatcherService.linksStream,
      initialData: ClipboardWatcherService.capturedLinks,
      builder: (context, snapshot) {
        final links = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppTheme.accentCyan),
                    const SizedBox(width: 6),
                    const Text('Auto-Watch Clipboard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkTextPrimary)),
                    const SizedBox(width: 8),
                    Switch(
                      value: ClipboardWatcherService.isWatching,
                      activeThumbColor: AppTheme.accentCyan,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            ClipboardWatcherService.startWatching();
                          } else {
                            ClipboardWatcherService.stopWatching();
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (links.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 14, color: AppTheme.accentRose),
                    label: const Text('Clear', style: TextStyle(fontSize: 11, color: AppTheme.accentRose)),
                    onPressed: () {
                      setState(() {
                        ClipboardWatcherService.clearCapturedLinks();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: links.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.content_paste, size: 36, color: AppTheme.darkTextSecondary),
                          SizedBox(height: 8),
                          Text('Copy any media link in Windows to capture here', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: links.length,
                      itemBuilder: (context, i) {
                        final link = links[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link, size: 15, color: AppTheme.accentCyan),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  link,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.darkTextPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryLight,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  final fname = link.split('/').last.split('?').first.isEmpty ? 'clip_download.mp4' : link.split('/').last.split('?').first;
                                  final detected = DetectedMedia(
                                    id: const Uuid().v4(),
                                    url: link,
                                    pageUrl: '',
                                    filename: fname,
                                    mediaType: link.toLowerCase().contains('.m3u8') ? MediaType.stream : MediaType.video,
                                    extension: fname.contains('.') ? '.${fname.split('.').last}' : '.mp4',
                                    detectedAt: DateTime.now(),
                                  );
                                  ref.read(downloadQueueProvider.notifier).addMediaToQueue(detected);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Added to queue: ${detected.filename}')),
                                  );
                                },
                                child: const Text('Download', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
