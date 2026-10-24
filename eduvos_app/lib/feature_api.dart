import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const _authApiUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2/Hackathon_Project/eduvos_app/api/auth.php',
);
const _featureChannel = MethodChannel('eduvos/features');

class FeatureApiException implements Exception {
  const FeatureApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FeatureApi {
  static Future<Map<String, dynamic>> marketplace(String token) async {
    return _request('marketplace', 'list', token);
  }

  static Future<int> createMarketplaceListing({
    required String token,
    required String type,
    required String title,
    required String description,
    String? price,
  }) async {
    final response = await _request(
      'marketplace',
      type == 'product' ? 'createProduct' : 'createService',
      token,
      {
        'title': title,
        'description': description,
        if (price != null && price.isNotEmpty) 'price': price,
      },
    );
    final id = response['id'];
    if (id is! int || id < 1) {
      throw const FeatureApiException(
        'The server did not return the new listing ID.',
      );
    }
    return id;
  }

  static Future<void> deleteMarketplaceListing({
    required String token,
    required String type,
    required int id,
  }) async {
    await _request('marketplace', 'delete', token, {'type': type, 'id': id});
  }

  static Future<void> updateMarketplaceListing({
    required String token,
    required String type,
    required int id,
    required String title,
    required String description,
    String? price,
  }) async {
    await _request('marketplace', 'update', token, {
      'type': type,
      'id': id,
      'title': title,
      'description': description,
      if (price != null && price.isNotEmpty) 'price': price,
    });
  }

  static Future<void> uploadProductImages({
    required String token,
    required int productId,
    required List<XFile> images,
  }) async {
    if (images.isEmpty) return;
    final endpoint = _endpoint('marketplace');
    late final int statusCode;
    late final String responseBody;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final response = await _featureChannel.invokeMapMethod<String, dynamic>(
          'marketplace.uploadImages',
          {
            'endpoint': endpoint.toString(),
            'token': token,
            'data': {
              'product_id': productId,
              'files': images.map((image) => image.path).toList(),
            },
          },
        );
        if (response == null ||
            response['statusCode'] is! int ||
            response['body'] is! String) {
          throw const FeatureApiException(
            'The Android photo upload returned an invalid response.',
          );
        }
        statusCode = response['statusCode'] as int;
        responseBody = response['body'] as String;
      } on PlatformException catch (error) {
        throw FeatureApiException(
          error.message ?? 'The product photos could not be uploaded.',
        );
      } on MissingPluginException {
        throw const FeatureApiException(
          'The Android photo upload is unavailable. Rebuild and reinstall the app.',
        );
      }
    } else {
      try {
        final request = http.MultipartRequest('POST', endpoint)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['action'] = 'upload_images'
          ..fields['product_id'] = '$productId';
        for (final image in images) {
          final bytes = await image.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'images[]',
              bytes,
              filename: image.name,
            ),
          );
        }
        final response = await http.Response.fromStream(await request.send());
        statusCode = response.statusCode;
        responseBody = response.body;
      } on http.ClientException {
        throw const FeatureApiException(
          'Could not connect to the PHP feature API. Check that Apache is running and the API URL is correct.',
        );
      }
    }

    Map<String, dynamic> decoded;
    try {
      final json = jsonDecode(responseBody);
      if (json is! Map) throw const FormatException();
      decoded = Map<String, dynamic>.from(json);
    } on FormatException {
      throw FeatureApiException(
        'The photo API returned invalid JSON (HTTP $statusCode).',
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      final message = decoded['message'];
      throw FeatureApiException(
        message is String
            ? message
            : 'The product photos could not be uploaded.',
      );
    }
  }

  static Uri productImageUrl(int imageId) {
    final endpoint = _endpoint('marketplace');
    return endpoint.replace(
      path: endpoint.path.replaceFirst(RegExp(r'[^/]+$'), 'product_image.php'),
      queryParameters: {'id': '$imageId'},
    );
  }

  static Future<List<dynamic>> communities(String token) async {
    final response = await _request('community', 'list', token);
    final data = response['data'];
    if (data is! List) {
      throw const FeatureApiException(
        'The server returned invalid communities.',
      );
    }
    return data;
  }

  static Future<void> setCommunityMembership({
    required String token,
    required int communityId,
    required bool join,
  }) async {
    await _request('community', join ? 'join' : 'leave', token, {
      'community_id': communityId,
    });
  }

  static Future<List<dynamic>> ideas(String token) async {
    final response = await _request('tank', 'list', token);
    final data = response['data'];
    if (data is! List) {
      throw const FeatureApiException('The server returned invalid ideas.');
    }
    return data;
  }

  static Future<void> createIdea({
    required String token,
    required String title,
    required String description,
  }) async {
    await _request('tank', 'create', token, {
      'title': title,
      'description': description,
    });
  }

  static Future<void> deleteIdea({
    required String token,
    required int id,
  }) async {
    await _request('tank', 'delete', token, {'id': id});
  }

  static Future<List<dynamic>> bursaries(String token) async {
    final response = await _request('bursaries', 'list', token);
    final data = response['data'];
    if (data is! List) {
      throw const FeatureApiException('The server returned invalid bursaries.');
    }
    return data;
  }

  static Future<void> createBursary({
    required String token,
    required String companyName,
    required String name,
    required String details,
    required String applicationUrl,
  }) async {
    await _request('bursaries', 'create', token, {
      'company_name': companyName,
      'name': name,
      'details': details,
      'application_url': applicationUrl,
    });
  }

  static Future<Map<String, dynamic>> _request(
    String feature,
    String operation,
    String token, [
    Map<String, Object> data = const {},
  ]) async {
    final endpoint = _endpoint(feature);
    late final int statusCode;
    late final String responseBody;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final response = await _featureChannel.invokeMapMethod<String, dynamic>(
          '$feature.$operation',
          {'endpoint': endpoint.toString(), 'token': token, 'data': data},
        );
        if (response == null ||
            response['statusCode'] is! int ||
            response['body'] is! String) {
          throw const FeatureApiException(
            'The Android feature API returned an invalid response.',
          );
        }
        statusCode = response['statusCode'] as int;
        responseBody = response['body'] as String;
      } on PlatformException catch (error) {
        throw FeatureApiException(
          error.message ?? 'The feature request failed on Android.',
        );
      } on MissingPluginException {
        throw const FeatureApiException(
          'The Android feature bridge is unavailable. Rebuild and reinstall the app.',
        );
      }
    } else {
      try {
        final body = <String, Object>{...data};
        if (operation != 'list') body['action'] = operation;
        if (operation == 'createProduct') body['type'] = 'product';
        if (operation == 'createService') body['type'] = 'service';
        if (operation == 'list') {
          final response = await http.get(
            endpoint,
            headers: {'Authorization': 'Bearer $token'},
          );
          statusCode = response.statusCode;
          responseBody = response.body;
        } else {
          final response = await http.post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(body),
          );
          statusCode = response.statusCode;
          responseBody = response.body;
        }
      } on http.ClientException {
        throw const FeatureApiException(
          'Could not connect to the PHP feature API. Check that Apache is running and the API URL is correct.',
        );
      }
    }

    Map<String, dynamic> decoded;
    try {
      final json = jsonDecode(responseBody);
      if (json is! Map) throw const FormatException();
      decoded = Map<String, dynamic>.from(json);
    } on FormatException {
      throw FeatureApiException(
        'The feature API returned invalid JSON (HTTP $statusCode).',
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      final message = decoded['message'];
      throw FeatureApiException(
        message is String ? message : 'The feature request failed.',
      );
    }
    return decoded;
  }

  static Uri _endpoint(String feature) {
    final authUri = Uri.parse(_authApiUrl);
    final fileName = switch (feature) {
      'marketplace' => 'marketplace.php',
      'community' => 'communities.php',
      'tank' => 'ideas.php',
      'bursaries' => 'bursaries.php',
      _ => throw ArgumentError.value(feature, 'feature'),
    };
    return authUri.replace(
      path: authUri.path.replaceFirst(RegExp(r'[^/]+$'), fileName),
      query: null,
      fragment: null,
    );
  }
}
