import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../../features/settings/domain/models/app_settings.dart';
import '../constants/app_constants.dart';

class DioClient {
  static Dio createDio(AppSettings settings, {String? refererUrl, Map<String, String>? customHeaders}) {
    final dio = Dio();

    dio.options.connectTimeout = Duration(seconds: settings.connectionTimeoutSeconds);
    dio.options.receiveTimeout = Duration(seconds: settings.connectionTimeoutSeconds);

    final headers = <String, dynamic>{
      'User-Agent': AppConstants.defaultUserAgent,
      if (refererUrl != null && refererUrl.isNotEmpty) 'Referer': refererUrl,
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

        // Trust certificate check
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

        return client;
      },
    );

    return dio;
  }
}
