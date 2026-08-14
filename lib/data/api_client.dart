import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../global.dart';

/// A failure the server described, or the network refusing to carry the call.
///
/// [fields] carries the per-field messages a validation failure comes back
/// with, so a form can paint the error under the box that caused it.
class ApiException implements Exception {
  ApiException(this.status, this.message, [this.fields]);

  final int status;
  final String message;
  final Map<String, String>? fields;

  /// Nothing reached the server at all.
  bool get isOffline => status == 0;

  /// The token is gone, expired or belongs to a deactivated account.
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status): $message';
}

/// Where the bearer token lives between launches. The Keychain on iOS and
/// EncryptedSharedPreferences on Android — never plain preferences, because a
/// two-year token is worth as much as the password that produced it.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      return await _storage.read(key: kTokenKey);
    } on PlatformException {
      // A keystore that lost its key (app reinstalled over itself, restored
      // backup) reads as corrupt rather than empty. Treat it as signed out.
      await clear();
      return null;
    }
  }

  Future<void> write(String token) => _storage.write(key: kTokenKey, value: token);

  Future<void> clear() async {
    try {
      await _storage.delete(key: kTokenKey);
    } on PlatformException {
      // Nothing to do — the goal was for the token to be gone.
    }
  }
}

/// The one place the app talks to the server.
///
/// Every call carries `Authorization: Bearer <token>`; there is no cookie and
/// no CSRF token to echo, because a bearer header cannot be attached by a
/// third-party site the way a cookie can.
class ApiClient {
  ApiClient({required this.tokenStore, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: kApiUrl,
      connectTimeout: kConnectTimeout,
      receiveTimeout: kReceiveTimeout,
      headers: {'Accept': 'application/json'},
      // Errors are read off the response body, so let every status through and
      // decide here rather than in a catch block.
      validateStatus: (_) => true,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = _token ??= await tokenStore.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStore tokenStore;

  /// Cached so a screenful of thumbnails does not hit the keychain once each.
  String? _token;

  /// Fires when a call comes back 401 — the shell listens and shows sign-in.
  final _unauthorized = StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _unauthorized.stream;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> setToken(String token) async {
    _token = token;
    await tokenStore.write(token);
  }

  Future<void> clearToken() async {
    _token = null;
    await tokenStore.clear();
  }

  /// Loads the stored token at boot. Returns true if there is one to try.
  Future<bool> restore() async {
    _token = await tokenStore.read();
    return hasToken;
  }

  /// Headers an image widget needs to fetch a photo straight from the API.
  Map<String, String> get imageHeaders =>
      hasToken ? {'Authorization': 'Bearer $_token'} : const {};

  // ── verbs ───────────────────────────────────────────────────────────────

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          contentType: body == null ? null : Headers.jsonContentType,
        ),
      );
    } on DioException catch (failure) {
      throw _networkFailure(failure);
    }
    return _unwrap(response);
  }

  /// Uploads one photo and returns its stored metadata. The expense form
  /// collects the ids first; saving the expense then claims them.
  Future<dynamic> uploadFile({
    required String filePath,
    required String filename,
    required String projectId,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      'projectId': projectId,
    });

    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        Api.files,
        data: form,
        cancelToken: cancelToken,
        options: Options(sendTimeout: kUploadTimeout, receiveTimeout: kUploadTimeout),
      );
    } on DioException catch (failure) {
      throw _networkFailure(failure);
    }
    return _unwrap(response);
  }

  /// Fetches a stored file as raw bytes.
  ///
  /// Everything else on this client speaks JSON; a PDF cannot. It also cannot
  /// be handed to the phone as a plain URL, because the file sits behind the
  /// same bearer token as the rest of the API — so it is pulled down here and
  /// written to a temp file for the system viewer to open.
  Future<List<int>> downloadBytes(String path) async {
    Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (failure) {
      throw _networkFailure(failure);
    }

    final status = response.statusCode ?? 0;
    if (status == 401) {
      _unauthorized.add(null);
    }
    if (status < 200 || status >= 300) {
      throw ApiException(status, _defaultMessage(status));
    }
    return response.data ?? const [];
  }

  /// Turns the response into data, or into the failure it describes.
  dynamic _unwrap(Response<dynamic> response) {
    final status = response.statusCode ?? 0;

    if (status == 401) {
      _unauthorized.add(null);
    }
    if (status >= 200 && status < 300) {
      return response.data;
    }

    final payload = response.data;
    String? message;
    Map<String, String>? fields;

    if (payload is Map) {
      final raw = payload['message'];
      if (raw is String && raw.isNotEmpty) message = raw;

      final rawFields = payload['fields'];
      if (rawFields is Map) {
        fields = rawFields.map((key, value) => MapEntry('$key', '$value'));
      }
    }

    throw ApiException(status, message ?? _defaultMessage(status), fields);
  }

  ApiException _networkFailure(DioException failure) {
    if (failure.type == DioExceptionType.cancel) {
      return ApiException(0, 'Cancelled.');
    }
    if (failure.type == DioExceptionType.connectionTimeout ||
        failure.type == DioExceptionType.receiveTimeout ||
        failure.type == DioExceptionType.sendTimeout) {
      return ApiException(0, 'The server took too long to answer. Try again.');
    }
    // A wrong server address in global.dart lands here, so say where it points.
    return ApiException(0, 'Cannot reach Bunyad at $kServerUrl. Check your connection.');
  }

  static String _defaultMessage(int status) {
    if (status == 401) return 'Please sign in.';
    if (status == 403) return 'You do not have access to this.';
    if (status == 404) return 'That is not here any more.';
    if (status == 413) return 'That file is too large.';
    if (status >= 500) return 'Something went wrong on the server.';
    return 'That did not work.';
  }

  void dispose() => _unauthorized.close();
}
