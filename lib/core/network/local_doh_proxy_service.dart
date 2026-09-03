import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../storage/hive_service.dart';

class LocalDohProxyService {
  static HttpServer? _server;
  static int _port = 0;
  static final HttpClient _dohHttpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
  static final Map<String, List<InternetAddress>> _dnsCache = {};

  static int get port => _port;
  static bool get isRunning => _server != null && _port > 0;

  /// Starts the embedded Local DoH Proxy on 127.0.0.1
  static Future<int> start() async {
    if (isRunning) return _port;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;

      _server!.listen((HttpRequest request) async {
        if (request.method == 'CONNECT') {
          _handleConnect(request);
        } else {
          _handleHttp(request);
        }
      }, onError: (e) {});

      return _port;
    } catch (_) {
      return 0;
    }
  }

  static String _getActiveDohUrl() {
    try {
      final settings = HiveService.getSettings();
      if (settings.selectedDnsPreset == 'Google Public DNS (8.8.8.8)' || settings.selectedDnsPreset.contains('Google')) {
        return 'https://8.8.8.8/resolve';
      } else if (settings.selectedDnsPreset.contains('AdGuard')) {
        return 'https://94.140.14.14/dns-query';
      } else if (settings.selectedDnsPreset.contains('Quad9')) {
        return 'https://9.9.9.9/dns-query';
      } else if (settings.selectedDnsPreset == 'Custom DNS / DoH' && settings.customDohUrl.isNotEmpty) {
        return settings.customDohUrl;
      }
    } catch (_) {}
    // Default to direct IP Cloudflare DoH (Cannot be blocked by ISP DNS)
    return 'https://1.1.1.1/dns-query';
  }

  /// Resolves hostname via DNS-over-HTTPS (DoH) with Direct IP endpoints
  static Future<List<InternetAddress>> resolveDoh(String host) async {
    final parsed = InternetAddress.tryParse(host);
    if (parsed != null) return [parsed];

    if (_dnsCache.containsKey(host)) return _dnsCache[host]!;

    final dohEndpoint = _getActiveDohUrl();
    try {
      final uri = Uri.parse('$dohEndpoint?name=${Uri.encodeComponent(host)}&type=A');
      final req = await _dohHttpClient.getUrl(uri);
      req.headers.set('Accept', 'application/dns-json');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final answers = json['Answer'] as List<dynamic>?;
        if (answers != null && answers.isNotEmpty) {
          final addresses = <InternetAddress>[];
          for (final a in answers) {
            final data = a['data'] as String?;
            final type = a['type'] as int?;
            if (type == 1 && data != null) {
              final ip = InternetAddress.tryParse(data);
              if (ip != null) addresses.add(ip);
            }
          }
          if (addresses.isNotEmpty) {
            _dnsCache[host] = addresses;
            return addresses;
          }
        }
      }
    } catch (_) {}

    // Fallback secondary query to Cloudflare 1.1.1.1 if custom endpoint failed
    try {
      final uri = Uri.parse('https://1.1.1.1/dns-query?name=${Uri.encodeComponent(host)}&type=A');
      final req = await _dohHttpClient.getUrl(uri);
      req.headers.set('Accept', 'application/dns-json');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final answers = json['Answer'] as List<dynamic>?;
        if (answers != null && answers.isNotEmpty) {
          final addresses = <InternetAddress>[];
          for (final a in answers) {
            final data = a['data'] as String?;
            final type = a['type'] as int?;
            if (type == 1 && data != null) {
              final ip = InternetAddress.tryParse(data);
              if (ip != null) addresses.add(ip);
            }
          }
          if (addresses.isNotEmpty) {
            _dnsCache[host] = addresses;
            return addresses;
          }
        }
      }
    } catch (_) {}

    // Fallback to system DNS lookup
    try {
      final systemIps = await InternetAddress.lookup(host);
      if (systemIps.isNotEmpty) {
        _dnsCache[host] = systemIps;
        return systemIps;
      }
    } catch (_) {}

    return [];
  }

  /// Handles HTTPS tunneling (CONNECT method)
  static void _handleConnect(HttpRequest request) async {
    Socket? clientSocket;
    try {
      clientSocket = await request.response.detachSocket(writeHeaders: false);
    } catch (_) {
      return;
    }

    String host = request.uri.host;
    int port = request.uri.port > 0 ? request.uri.port : 443;
    if (host.isEmpty) {
      String raw = request.uri.toString();
      if (raw.startsWith('//')) raw = raw.substring(2);
      if (raw.startsWith('/')) raw = raw.substring(1);
      final colon = raw.indexOf(':');
      if (colon != -1) {
        host = raw.substring(0, colon);
        port = int.tryParse(raw.substring(colon + 1)) ?? 443;
      } else {
        host = raw;
      }
    }

    host = host.replaceAll('[', '').replaceAll(']', '');

    try {
      final ips = await resolveDoh(host);
      if (ips.isEmpty) {
        clientSocket.write('HTTP/1.1 502 Bad Gateway\r\n\r\n');
        await clientSocket.close();
        return;
      }

      final targetSocket = await Socket.connect(ips.first, port, timeout: const Duration(seconds: 12));
      clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await clientSocket.flush();

      // Bi-directional pipe
      targetSocket.listen(
        (data) => clientSocket?.add(data),
        onDone: () {
          clientSocket?.destroy();
          targetSocket.destroy();
        },
        onError: (_) {
          clientSocket?.destroy();
          targetSocket.destroy();
        },
        cancelOnError: true,
      );

      clientSocket.listen(
        (data) => targetSocket.add(data),
        onDone: () {
          targetSocket.destroy();
          clientSocket?.destroy();
        },
        onError: (_) {
          targetSocket.destroy();
          clientSocket?.destroy();
        },
        cancelOnError: true,
      );
    } catch (_) {
      try {
        clientSocket.write('HTTP/1.1 502 Bad Gateway\r\n\r\n');
        await clientSocket.close();
      } catch (_) {}
    }
  }

  /// Handles standard HTTP requests (GET, POST, etc.)
  static void _handleHttp(HttpRequest request) async {
    try {
      final host = request.headers.host ?? request.uri.host;
      if (host.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      final ips = await resolveDoh(host);
      if (ips.isEmpty) {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
        return;
      }

      final port = request.uri.port > 0 ? request.uri.port : 80;
      final targetSocket = await Socket.connect(ips.first, port, timeout: const Duration(seconds: 10));

      final clientSocket = await request.response.detachSocket(writeHeaders: false);
      
      final reqLine = '${request.method} ${request.uri.path}${request.uri.hasQuery ? '?${request.uri.query}' : ''} HTTP/1.1\r\n';
      targetSocket.write(reqLine);
      request.headers.forEach((name, values) {
        for (final val in values) {
          targetSocket.write('$name: $val\r\n');
        }
      });
      targetSocket.write('\r\n');
      await targetSocket.flush();

      targetSocket.listen(
        (data) => clientSocket.add(data),
        onDone: () => clientSocket.destroy(),
        onError: (_) => clientSocket.destroy(),
        cancelOnError: true,
      );
      clientSocket.listen(
        (data) => targetSocket.add(data),
        onDone: () => targetSocket.destroy(),
        onError: (_) => targetSocket.destroy(),
        cancelOnError: true,
      );
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Clears in-memory DNS cache (e.g. when user changes DNS preset)
  static void clearCache() {
    _dnsCache.clear();
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }
}
