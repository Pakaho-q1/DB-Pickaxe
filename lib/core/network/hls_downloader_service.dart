import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../features/settings/domain/models/app_settings.dart';
import '../storage/cache_paths.dart';
import 'dio_client.dart';

class HlsSegment {
  final int index;
  final String url;
  final double duration;

  const HlsSegment({
    required this.index,
    required this.url,
    required this.duration,
  });
}

class HlsDownloaderService {
  /// Parses M3U8 playlist text and extracts all media segment URLs
  static List<HlsSegment> parseM3u8Playlist(String m3u8Content, String baseUrl) {
    final lines = m3u8Content.split(RegExp(r'\r?\n'));
    final segments = <HlsSegment>[];
    double currentDuration = 0.0;
    final baseUri = Uri.parse(baseUrl);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final durStr = line.substring(8).split(',').first.trim();
        currentDuration = double.tryParse(durStr) ?? 0.0;
      } else if (!line.startsWith('#')) {
        // Segment URL
        Uri segmentUri;
        try {
          segmentUri = Uri.parse(line);
          if (!segmentUri.hasScheme) {
            segmentUri = baseUri.resolve(line);
          }
        } catch (_) {
          segmentUri = baseUri.resolve(line);
        }

        segments.add(HlsSegment(
          index: segments.length,
          url: segmentUri.toString(),
          duration: currentDuration,
        ));
        currentDuration = 0.0;
      }
    }

    return segments;
  }

  /// Downloads HLS segments in parallel using concurrency pool
  static Future<void> downloadHlsSegments({
    required String m3u8Url,
    required Directory tempDir,
    required AppSettings settings,
    required Function(int completed, int total, double progress) onProgress,
    CancelToken? cancelToken,
    Map<String, String>? headers,
  }) async {
    final dio = DioClient.createDio(settings, targetUrl: m3u8Url, customHeaders: headers);

    // 1. Fetch M3U8 Playlist
    final resp = await dio.get<String>(
      m3u8Url,
      options: Options(responseType: ResponseType.plain),
      cancelToken: cancelToken,
    );

    final m3u8Text = resp.data ?? '';
    final segments = parseM3u8Playlist(m3u8Text, m3u8Url);

    if (segments.isEmpty) {
      throw Exception('No media segments found in M3U8 playlist.');
    }

    final total = segments.length;
    int completed = 0;
    final concurrency = (settings.threadsPerDownload).clamp(2, 16);

    // 2. Parallel Worker Pool
    final segmentQueue = List<HlsSegment>.from(segments);
    final futures = <Future<void>>[];

    for (int workerId = 0; workerId < concurrency; workerId++) {
      futures.add(Future.microtask(() async {
        while (segmentQueue.isNotEmpty) {
          if (cancelToken != null && cancelToken.isCancelled) return;

          HlsSegment segment;
          try {
            segment = segmentQueue.removeAt(0);
          } catch (_) {
            break;
          }

          final segFile = File('${tempDir.path}/seg_${segment.index.toString().padLeft(5, '0')}.ts');
          if (!await segFile.exists()) {
            await dio.download(
              segment.url,
              segFile.path,
              cancelToken: cancelToken,
              options: Options(responseType: ResponseType.bytes),
            );
          }

          completed++;
          onProgress(completed, total, completed / total);
        }
      }));
    }

    await Future.wait(futures);

    if (cancelToken != null && cancelToken.isCancelled) {
      throw Exception('Download cancelled');
    }
  }

  /// Concatenates all downloaded .ts segments and converts into .mp4 using FFmpeg
  static Future<void> concatenateSegmentsToMp4({
    required Directory tempDir,
    required String outputPath,
  }) async {
    final segFiles = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ts'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (segFiles.isEmpty) {
      throw Exception('No segment files to concatenate.');
    }

    // Write file list for ffmpeg concat demuxer
    final listFile = File('${tempDir.path}/concat_list.txt');
    final sink = listFile.openWrite();
    for (final seg in segFiles) {
      sink.writeln("file '${seg.path.replaceAll('\\', '/')}'");
    }
    await sink.flush();
    await sink.close();

    final ffmpegPath = '${CachePaths.binDir.path}/ffmpeg.exe';
    if (await File(ffmpegPath).exists()) {
      final result = await Process.run(ffmpegPath, [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-c',
        'copy',
        outputPath,
      ]);

      if (result.exitCode != 0) {
        // Fallback: direct binary concatenation
        await _directBinaryConcat(segFiles, outputPath);
      }
    } else {
      // Fallback: direct binary concatenation of MPEG-TS stream
      await _directBinaryConcat(segFiles, outputPath);
    }
  }

  static Future<void> _directBinaryConcat(List<File> files, String outputPath) async {
    final outFile = File(outputPath);
    final sink = outFile.openWrite();
    for (final f in files) {
      await sink.addStream(f.openRead());
    }
    await sink.flush();
    await sink.close();
  }
}
