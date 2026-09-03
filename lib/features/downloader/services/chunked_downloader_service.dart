import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/cache_paths.dart';
import '../../settings/domain/models/app_settings.dart';

class ChunkProgress {
  final int index;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  bool isCompleted;

  ChunkProgress({
    required this.index,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.isCompleted = false,
  });

  int get totalChunkBytes => (endByte - startByte) + 1;

  Map<String, dynamic> toMap() => {
        'index': index,
        'startByte': startByte,
        'endByte': endByte,
        'downloadedBytes': downloadedBytes,
        'isCompleted': isCompleted,
      };

  factory ChunkProgress.fromMap(Map<String, dynamic> map) => ChunkProgress(
        index: map['index'] as int,
        startByte: map['startByte'] as int,
        endByte: map['endByte'] as int,
        downloadedBytes: map['downloadedBytes'] as int? ?? 0,
        isCompleted: map['isCompleted'] as bool? ?? false,
      );
}

class ChunkedDownloaderService {
  static final Map<String, List<CancelToken>> _activeCancelTokens = {};

  /// Cleanly delete task temp folder if task is removed
  static Future<void> deleteTaskTempFolder(String taskId) async {
    try {
      final taskTempDir = Directory('${CachePaths.tempDir.path}\\task_$taskId');
      if (await taskTempDir.exists()) {
        await taskTempDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Performs a high-speed multi-threaded or resumable download
  static Future<void> download({
    required String taskId,
    required String url,
    required String destinationPath,
    required AppSettings settings,
    String? refererUrl,
    Map<String, String>? customHeaders,
    CancelToken? parentCancelToken,
    required void Function(int receivedBytes, int totalBytes, double speedBytesPerSec, bool isResumable, int chunkCount) onProgress,
  }) async {
    final dio = DioClient.createDio(
      settings,
      targetUrl: url,
      refererUrl: refererUrl,
      customHeaders: customHeaders,
    );

    final childTokens = <CancelToken>[];
    _activeCancelTokens[taskId] = childTokens;

    // 1. Prepare isolated task temp directory in .pickaxe-cache/temp/task_$taskId
    final taskTempDir = Directory('${CachePaths.tempDir.path}\\task_$taskId');
    if (!await taskTempDir.exists()) {
      await taskTempDir.create(recursive: true);
    }

    // 2. Probe Server Headers (HEAD / Partial GET)
    int totalBytes = 0;
    bool supportsRange = false;

    try {
      final headResponse = await dio.head(
        url,
        cancelToken: parentCancelToken,
        options: Options(
          validateStatus: (status) => status != null && status < 400,
          followRedirects: true,
        ),
      );

      final acceptRanges = headResponse.headers.value('accept-ranges') ?? '';
      supportsRange = acceptRanges.toLowerCase().contains('bytes');

      final lengthStr = headResponse.headers.value('content-length');
      if (lengthStr != null) {
        totalBytes = int.tryParse(lengthStr) ?? 0;
      }
    } catch (_) {
      // If HEAD fails, try probe with Range: bytes=0-0
      try {
        final probeResponse = await dio.get(
          url,
          cancelToken: parentCancelToken,
          options: Options(
            headers: {'Range': 'bytes=0-0'},
            validateStatus: (status) => status == 206 || status == 200,
            followRedirects: true,
          ),
        );

        if (probeResponse.statusCode == 206) {
          supportsRange = true;
          final cr = probeResponse.headers.value('content-range');
          if (cr != null) {
            final match = RegExp(r'/(\d+)').firstMatch(cr);
            if (match != null) {
              totalBytes = int.tryParse(match.group(1)!) ?? 0;
            }
          }
        } else {
          final lengthStr = probeResponse.headers.value('content-length');
          if (lengthStr != null) totalBytes = int.tryParse(lengthStr) ?? 0;
        }
      } catch (_) {}
    }

    final metaFile = File('${taskTempDir.path}\\download.meta');
    final minChunkBytes = settings.minChunkSizeMB * 1024 * 1024;
    final int threadCount = settings.threadsPerDownload.clamp(1, 16);

    final bool canChunk = settings.enableChunkedDownload &&
        supportsRange &&
        totalBytes >= minChunkBytes &&
        threadCount > 1;

    if (canChunk) {
      try {
        await _executeMultiThreadedDownload(
          taskId: taskId,
          url: url,
          taskTempDir: taskTempDir,
          destinationPath: destinationPath,
          totalBytes: totalBytes,
          threadCount: threadCount,
          settings: settings,
          metaFile: metaFile,
          refererUrl: refererUrl,
          customHeaders: customHeaders,
          parentCancelToken: parentCancelToken,
          onProgress: onProgress,
        );
      } catch (e) {
        // If range download failed (e.g. Instagram/CDN rejected chunk range), instantly fallback to single-stream direct download
        if (parentCancelToken?.isCancelled ?? false) rethrow;
        await _executeDirectSingleDownload(
          taskId: taskId,
          url: url,
          taskTempDir: taskTempDir,
          destinationPath: destinationPath,
          totalBytes: totalBytes,
          supportsRange: false,
          settings: settings,
          refererUrl: refererUrl,
          customHeaders: customHeaders,
          parentCancelToken: parentCancelToken,
          onProgress: onProgress,
        );
      }
    } else {
      await _executeDirectSingleDownload(
        taskId: taskId,
        url: url,
        taskTempDir: taskTempDir,
        destinationPath: destinationPath,
        totalBytes: totalBytes,
        supportsRange: supportsRange,
        settings: settings,
        refererUrl: refererUrl,
        customHeaders: customHeaders,
        parentCancelToken: parentCancelToken,
        onProgress: onProgress,
      );
    }
  }

  /// Multi-Threaded Chunked Download Implementation
  static Future<void> _executeMultiThreadedDownload({
    required String taskId,
    required String url,
    required Directory taskTempDir,
    required String destinationPath,
    required int totalBytes,
    required int threadCount,
    required AppSettings settings,
    required File metaFile,
    String? refererUrl,
    Map<String, String>? customHeaders,
    CancelToken? parentCancelToken,
    required void Function(int receivedBytes, int totalBytes, double speedBytesPerSec, bool isResumable, int chunkCount) onProgress,
  }) async {
    List<ChunkProgress> chunks = [];

    // Check existing .meta file for resuming
    if (await metaFile.exists()) {
      try {
        final metaContent = await metaFile.readAsString();
        final metaJson = jsonDecode(metaContent) as Map<String, dynamic>;
        if (metaJson['totalBytes'] == totalBytes && metaJson['url'] == url) {
          final list = metaJson['chunks'] as List<dynamic>;
          chunks = list.map((e) => ChunkProgress.fromMap(Map<String, dynamic>.from(e as Map))).toList();
        }
      } catch (_) {}
    }

    // Initialize chunks if not resuming
    if (chunks.isEmpty || chunks.length != threadCount) {
      chunks = [];
      final chunkSize = (totalBytes / threadCount).ceil();
      for (int i = 0; i < threadCount; i++) {
        final start = i * chunkSize;
        final end = (i == threadCount - 1) ? totalBytes - 1 : ((i + 1) * chunkSize) - 1;
        chunks.add(ChunkProgress(
          index: i,
          startByte: start,
          endByte: end,
          downloadedBytes: 0,
          isCompleted: false,
        ));
      }
      await _saveMeta(metaFile, url, totalBytes, chunks);
    }

    // Prepare cancellation tokens
    final chunkTokens = List.generate(threadCount, (_) => CancelToken());
    _activeCancelTokens[taskId] = chunkTokens;

    // Track overall speed
    var lastRecordedBytes = chunks.fold<int>(0, (sum, c) => sum + c.downloadedBytes);
    var lastTime = DateTime.now();

    void emitProgress() {
      final currentTotal = chunks.fold<int>(0, (sum, c) => sum + c.downloadedBytes);
      final now = DateTime.now();
      final diffMs = now.difference(lastTime).inMilliseconds;

      double speed = 0;
      if (diffMs >= 400) {
        final byteDiff = currentTotal - lastRecordedBytes;
        speed = byteDiff / (diffMs / 1000.0);
        lastRecordedBytes = currentTotal;
        lastTime = now;
      }

      onProgress(currentTotal, totalBytes, speed, true, threadCount);
    }

    // Download each chunk concurrently into taskTempDir
    final futures = <Future<void>>[];

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      if (chunk.isCompleted) continue;

      final partFile = File('${taskTempDir.path}\\part_$i');
      int existingBytes = 0;
      if (await partFile.exists()) {
        existingBytes = await partFile.length();
        if (existingBytes >= chunk.totalChunkBytes) {
          chunk.downloadedBytes = chunk.totalChunkBytes;
          chunk.isCompleted = true;
          continue;
        } else {
          chunk.downloadedBytes = existingBytes;
        }
      }

      final chunkFuture = _downloadSingleChunk(
        url: url,
        chunk: chunk,
        partFile: partFile,
        cancelToken: chunkTokens[i],
        parentCancelToken: parentCancelToken,
        settings: settings,
        refererUrl: refererUrl,
        customHeaders: customHeaders,
        onChunkProgress: (added) {
          chunk.downloadedBytes += added;
          emitProgress();
        },
      );
      futures.add(chunkFuture);
    }

    // Periodically save meta file for safe resume
    final metaTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _saveMeta(metaFile, url, totalBytes, chunks);
    });

    try {
      await Future.wait(futures);
    } finally {
      metaTimer.cancel();
      await _saveMeta(metaFile, url, totalBytes, chunks);
    }

    // 4. High-Performance Merge Chunks from taskTempDir into Final Output File (1 MB buffer)
    final finalFile = File(destinationPath);
    final parentDir = finalFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    if (await finalFile.exists()) {
      await finalFile.delete();
    }

    final outputRaf = await finalFile.open(mode: FileMode.writeOnly);
    const int bufferSize = 1024 * 1024; // 1 MB high-throughput buffer

    for (int i = 0; i < threadCount; i++) {
      final partFile = File('${taskTempDir.path}\\part_$i');
      if (await partFile.exists()) {
        final partRaf = await partFile.open(mode: FileMode.read);
        final fileLength = await partRaf.length();
        int bytesReadTotal = 0;

        while (bytesReadTotal < fileLength) {
          final toRead = (fileLength - bytesReadTotal).clamp(0, bufferSize);
          final buffer = await partRaf.read(toRead);
          await outputRaf.writeFrom(buffer);
          bytesReadTotal += buffer.length;
        }
        await partRaf.close();
      }
    }
    await outputRaf.flush();
    await outputRaf.close();

    // Clean up entire temporary task folder completely
    try {
      if (await taskTempDir.exists()) {
        await taskTempDir.delete(recursive: true);
      }
    } catch (_) {}

    onProgress(totalBytes, totalBytes, 0, true, threadCount);
  }

  /// Download a single range slice
  static Future<void> _downloadSingleChunk({
    required String url,
    required ChunkProgress chunk,
    required File partFile,
    required CancelToken cancelToken,
    CancelToken? parentCancelToken,
    required AppSettings settings,
    String? refererUrl,
    Map<String, String>? customHeaders,
    required void Function(int bytesReceivedInChunk) onChunkProgress,
  }) async {
    final dio = DioClient.createDio(
      settings,
      targetUrl: url,
      refererUrl: refererUrl,
      customHeaders: customHeaders,
    );

    final currentOffset = chunk.startByte + chunk.downloadedBytes;
    if (currentOffset > chunk.endByte) {
      chunk.isCompleted = true;
      return;
    }

    final headers = <String, dynamic>{
      'Range': 'bytes=$currentOffset-${chunk.endByte}',
    };

    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        validateStatus: (status) => status != null && status < 500,
      ),
      cancelToken: cancelToken,
    );

    if (response.statusCode != 206) {
      throw HttpException('Server rejected range request with status ${response.statusCode}');
    }

    final fileSink = partFile.openWrite(
      mode: chunk.downloadedBytes > 0 ? FileMode.append : FileMode.writeOnly,
    );

    final stream = response.data!.stream;
    final speedLimitBytesPerSec = settings.speedLimitKBps > 0 ? (settings.speedLimitKBps * 1024) / settings.threadsPerDownload : 0;

    await for (final data in stream) {
      if (parentCancelToken?.isCancelled ?? false) {
        cancelToken.cancel();
        break;
      }
      fileSink.add(data);
      onChunkProgress(data.length);

      // Apply speed limiter throttling if configured
      if (speedLimitBytesPerSec > 0 && data.isNotEmpty) {
        final expectedMs = (data.length / speedLimitBytesPerSec) * 1000;
        if (expectedMs > 2) {
          await Future.delayed(Duration(milliseconds: expectedMs.round()));
        }
      }
    }

    await fileSink.flush();
    await fileSink.close();
    chunk.isCompleted = true;
  }

  /// Single-connection download with Range resume fallback into taskTempDir
  static Future<void> _executeDirectSingleDownload({
    required String taskId,
    required String url,
    required Directory taskTempDir,
    required String destinationPath,
    required int totalBytes,
    required bool supportsRange,
    required AppSettings settings,
    String? refererUrl,
    Map<String, String>? customHeaders,
    CancelToken? parentCancelToken,
    required void Function(int receivedBytes, int totalBytes, double speedBytesPerSec, bool isResumable, int chunkCount) onProgress,
  }) async {
    final dio = DioClient.createDio(
      settings,
      targetUrl: url,
      refererUrl: refererUrl,
      customHeaders: customHeaders,
    );

    final tempSingleFile = File('${taskTempDir.path}\\single.part');
    int downloadedSoFar = 0;

    if (supportsRange && await tempSingleFile.exists()) {
      downloadedSoFar = await tempSingleFile.length();
    }

    final headers = <String, dynamic>{
      if (supportsRange && downloadedSoFar > 0) 'Range': 'bytes=$downloadedSoFar-',
    };

    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        validateStatus: (status) => status == 206 || status == 200,
      ),
      cancelToken: parentCancelToken,
    );

    final fileSink = tempSingleFile.openWrite(
      mode: (supportsRange && downloadedSoFar > 0) ? FileMode.append : FileMode.writeOnly,
    );

    var lastBytes = downloadedSoFar;
    var lastTime = DateTime.now();
    final speedLimitBytesPerSec = settings.speedLimitKBps > 0 ? settings.speedLimitKBps * 1024 : 0;

    await for (final data in response.data!.stream) {
      if (parentCancelToken?.isCancelled ?? false) break;

      fileSink.add(data);
      downloadedSoFar += data.length;

      final now = DateTime.now();
      final diffMs = now.difference(lastTime).inMilliseconds;
      double speed = 0;
      if (diffMs >= 400) {
        final byteDiff = downloadedSoFar - lastBytes;
        speed = byteDiff / (diffMs / 1000.0);
        lastBytes = downloadedSoFar;
        lastTime = now;
      }

      onProgress(downloadedSoFar, totalBytes > 0 ? totalBytes : downloadedSoFar, speed, supportsRange, 1);

      if (speedLimitBytesPerSec > 0 && data.isNotEmpty) {
        final expectedMs = (data.length / speedLimitBytesPerSec) * 1000;
        if (expectedMs > 2) {
          await Future.delayed(Duration(milliseconds: expectedMs.round()));
        }
      }
    }

    await fileSink.flush();
    await fileSink.close();

    final finalFile = File(destinationPath);
    final parentDir = finalFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    if (await finalFile.exists()) {
      await finalFile.delete();
    }

    await tempSingleFile.copy(destinationPath);

    // Clean up temp directory
    try {
      if (await taskTempDir.exists()) {
        await taskTempDir.delete(recursive: true);
      }
    } catch (_) {}

    onProgress(totalBytes > 0 ? totalBytes : downloadedSoFar, totalBytes > 0 ? totalBytes : downloadedSoFar, 0, supportsRange, 1);
  }

  static Future<void> _saveMeta(File metaFile, String url, int totalBytes, List<ChunkProgress> chunks) async {
    try {
      final json = jsonEncode({
        'url': url,
        'totalBytes': totalBytes,
        'chunks': chunks.map((c) => c.toMap()).toList(),
      });
      await metaFile.writeAsString(json);
    } catch (_) {}
  }

  static void cancel(String taskId) {
    if (_activeCancelTokens.containsKey(taskId)) {
      for (final t in _activeCancelTokens[taskId]!) {
        t.cancel();
      }
      _activeCancelTokens.remove(taskId);
    }
  }
}

