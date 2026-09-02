import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../../features/settings/domain/models/app_settings.dart';
import '../constants/app_constants.dart';
import 'cookie_manager_service.dart';

class DioClient {
  static Dio createDio(
    AppSettings settings, {
    String? targetUrl,
    String? refererUrl,
    Map<String, String>? customHeaders,
  }) {
    final dio = Dio();

    dio.options.connectTimeout = Duration(seconds: settings.connectionTimeoutSeconds);
    dio.options.receiveTimeout = Duration(seconds: settings.connectionTimeoutSeconds);

    // Retrieve active session cookies for the target domain
    String? sessionCookie;
    if (targetUrl != null && targetUrl.isNotEmpty) {
      sessionCookie = CookieManagerService.getCookieHeaderForUrl(targetUrl);
    } else if (refererUrl != null && refererUrl.isNotEmpty) {
      sessionCookie = CookieManagerService.getCookieHeaderForUrl(refererUrl);
    }

    final headers = <String, dynamic>{
      'User-Agent': AppConstants.defaultUserAgent,
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9,th;q=0.8',
      'Sec-Ch-Ua': '"Chromium";v="128", "Not;A=Brand";v="24"',
      'Sec-Ch-Ua-Mobile': '?0',
      'Sec-Ch-Ua-Platform': '"Windows"',
      'Sec-Fetch-Dest': 'video',
      'Sec-Fetch-Mode': 'no-cors',
      'Sec-Fetch-Site': 'cross-site',
      if (refererUrl != null && refererUrl.isNotEmpty) 'Referer': refererUrl,
      if (sessionCookie != null && sessionCookie.isNotEmpty) 'Cookie': sessionCookie,
      ...?customHeaders,
    };
    dio.options.headers = headers;

    // Apply Proxy if enabled
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();

        if (settings.proxyEnabled && settings.proxyHost.isNotEmpty) {
          client.findProxy = (uri) {
            return 'PROXY ${settings.proxyHost}:${settings.proxyPort}';
          };

          if (settings.proxyUsername.isNotEmpty) {
            client.addProxyCredentials(
              settings.proxyHost,
              settings.proxyPort,
              '',
              HttpClientBasicCredentials(settings.proxyUsername, settings.proxyPassword),
            );
          }
        }

        // In debug mode only, allow self-signed/invalid certificates for local dev servers.
        // In release builds, enforce full SSL certificate validation (default behaviour).
        if (kDebugMode) {
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        }

        return client;
      },
    );

    return dio;
  }
}
