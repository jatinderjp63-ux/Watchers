import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config.dart';

class TmdbHttpClient {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Authorization': 'Bearer ${Config.tmdbBearerToken}',
        'Accept': 'application/json',
      },
    ),
  );

  static Dio get instance {
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.maxConnectionsPerHost = 10;
      return client;
    };

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError) {
            final request = error.requestOptions;

            try {
              final response = await _dio.fetch(
                RequestOptions(
                  path: request.path,
                  baseUrl: request.baseUrl,
                  method: request.method,
                  queryParameters: request.queryParameters,
                  data: request.data,
                  headers: request.headers,
                  responseType: request.responseType,
                  connectTimeout: const Duration(seconds: 20),
                  receiveTimeout: const Duration(seconds: 20),
                ),
              );
              return handler.resolve(response);
            } catch (_) {
              return handler.next(error);
            }
          }

          return handler.next(error);
        },
      ),
    );

    return _dio;
  }
}