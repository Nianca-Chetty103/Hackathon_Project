import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const _apiUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2/Hackathon_Project/eduvos_app/api/auth.php',
);
const _androidAuthChannel = MethodChannel('eduvos/auth_api');

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({required this.token, required this.profile});

  final String token;
  final Map<String, dynamic> profile;
}

class AuthApi {
  static Future<AuthResult> signUp({
    required String role,
    required String firstName,
    required String surname,
    required String email,
    required String password,
    required String phoneNumber,
    String? studentNumber,
    String? lecturerNumber,
  }) async {
    final payload = <String, String>{
      'role': role,
      'first_name': firstName,
      'surname': surname,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
    };
    if (studentNumber != null) payload['student_number'] = studentNumber;
    if (lecturerNumber != null) payload['lecturer_number'] = lecturerNumber;
    return _authenticate('signup', payload);
  }

  static Future<AuthResult> signIn({
    required String role,
    required String email,
    required String password,
  }) {
    return _authenticate('login', {
      'role': role,
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _sendRequest(
      _profileUri(),
      method: 'GET',
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = _decodeResponse(response);
    final data = body['data'];
    if (data is! Map) {
      throw const AuthApiException('The server returned an invalid profile.');
    }
    final profile = data['profile'];
    return Map<String, dynamic>.from(profile is Map ? profile : data);
  }

  static Future<Map<String, dynamic>> getAccountSettings(String token) async {
    final response = await _sendRequest(
      _profileUri(),
      method: 'GET',
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = _decodeResponse(response);
    final data = body['data'];
    if (data is! Map || data['settings'] is! Map) {
      throw const AuthApiException(
        'The server returned invalid account settings.',
      );
    }
    return Map<String, dynamic>.from(data['settings'] as Map);
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    required Map<String, dynamic> profile,
  }) async {
    final response = await _sendRequest(
      _profileUri(),
      method: 'POST',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'action': 'update_profile', ...profile}),
    );
    final body = _decodeResponse(response);
    final updatedProfile = body['profile'];
    if (updatedProfile is! Map) {
      throw const AuthApiException('The server returned an invalid profile.');
    }
    return Map<String, dynamic>.from(updatedProfile);
  }

  static Future<void> updateAccountSettings({
    required String token,
    required bool darkMode,
    required bool notificationsEnabled,
  }) async {
    final response = await _sendRequest(
      _profileUri(),
      method: 'POST',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'action': 'update_settings',
        'dark_mode': darkMode,
        'notifications_enabled': notificationsEnabled,
      }),
    );
    _decodeResponse(response);
  }

  static Future<void> signOut(String token) async {
    final response = await _sendRequest(
      _profileUri(),
      method: 'POST',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'action': 'logout'}),
    );
    _decodeResponse(response);
  }

  static Future<AuthResult> _authenticate(
    String action,
    Map<String, String> payload,
  ) async {
    final response = await _sendRequest(
      _uri(action),
      method: 'POST',
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(payload),
    );
    final body = _decodeResponse(response);
    final data = body['data'];
    if (data is! Map || data['token'] is! String || data['profile'] is! Map) {
      throw const AuthApiException('The server returned an invalid response.');
    }
    return AuthResult(
      token: data['token'] as String,
      profile: Map<String, dynamic>.from(data['profile'] as Map),
    );
  }

  static Future<_ApiResponse> _sendRequest(
    Uri uri, {
    required String method,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final arguments = <String, Object>{
          'url': uri.toString(),
          'method': method,
          'headers': headers,
        };
        if (body != null) arguments['body'] = body;
        final response = await _androidAuthChannel
            .invokeMapMethod<String, dynamic>('request', arguments);
        if (response == null ||
            response['statusCode'] is! int ||
            response['body'] is! String) {
          throw const AuthApiException(
            'The Android API bridge returned an invalid response.',
          );
        }
        return _ApiResponse(
          response['statusCode'] as int,
          response['body'] as String,
        );
      } on PlatformException catch (error) {
        throw AuthApiException(
          error.message ?? 'The Android API request failed.',
        );
      } on MissingPluginException {
        throw const AuthApiException(
          'The Android API bridge is unavailable. Rebuild and reinstall the app.',
        );
      }
    }

    try {
      final response = method == 'GET'
          ? await http.get(uri, headers: headers)
          : await http.post(uri, headers: headers, body: body);
      return _ApiResponse(response.statusCode, response.body);
    } on http.ClientException {
      throw const AuthApiException(
        'Could not connect to the PHP API. Check that Apache is running and the API URL is correct.',
      );
    }
  }

  static Map<String, dynamic> _decodeResponse(_ApiResponse response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object.');
      }
      body = Map<String, dynamic>.from(decoded);
    } on FormatException {
      if (response.statusCode == 404) {
        throw const AuthApiException(
          'API endpoint not found (HTTP 404). Put the project under XAMPP htdocs and check API_BASE_URL.',
        );
      }
      throw AuthApiException(
        'The server did not return JSON (HTTP ${response.statusCode}). Check that Apache is serving the PHP API.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['message'];
      throw AuthApiException(
        message is String ? message : 'The request could not be completed.',
      );
    }
    return body;
  }

  static Uri _uri([String? action]) {
    final uri = Uri.parse(_apiUrl);
    return action == null
        ? uri
        : uri.replace(
            queryParameters: {...uri.queryParameters, 'action': action},
          );
  }

  static Uri _profileUri() {
    final authUri = Uri.parse(_apiUrl);
    return authUri.replace(
      path: authUri.path.replaceFirst(RegExp(r'[^/]+$'), 'profile.php'),
      query: null,
      fragment: null,
    );
  }
}

class _ApiResponse {
  const _ApiResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
