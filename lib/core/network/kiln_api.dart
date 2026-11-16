import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../format.dart';
import '../models/firing.dart';
import '../models/recipe.dart';
import '../models/sync_models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract class KilnApi {
  Future<bool> ping();

  Future<SyncResponse> pushAndPull({
    required String? since,
    required List<Recipe> recipes,
    required List<Firing> firings,
  });
}

class HttpKilnApi implements KilnApi {
  HttpKilnApi({required String baseUrl, http.Client? client})
      : baseUrl = _trim(baseUrl),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static String _trim(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  @override
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SyncResponse> pushAndPull({
    required String? since,
    required List<Recipe> recipes,
    required List<Firing> firings,
  }) async {
    final query = since == null ? '' : '?since=${Uri.encodeQueryComponent(since)}';
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/sync$query'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'recipes': recipes.map((recipe) => recipe.toJson()).toList(),
              'firings': firings.map((firing) => firing.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_errorMessage(response.body), statusCode: response.statusCode);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final conflicts = (json['conflicts'] as Map).cast<String, dynamic>();
      final changes = (json['changes'] as Map).cast<String, dynamic>();
      return SyncResponse(
        serverTime: parseIso(json['serverTime'] as String),
        applied: (json['applied'] as num).toInt(),
        recipeConflicts: _recipes(conflicts['recipes']),
        firingConflicts: _firings(conflicts['firings']),
        recipes: _recipes(changes['recipes']),
        firings: _firings(changes['firings']),
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The studio service timed out.');
    } on SocketException {
      throw ApiException('The studio service is unreachable.');
    } on FormatException {
      throw ApiException('The studio service returned an unreadable payload.');
    }
  }

  List<Recipe> _recipes(Object? raw) {
    return [
      for (final item in raw as List) Recipe.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  List<Firing> _firings(Object? raw) {
    return [
      for (final item in raw as List) Firing.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  String _errorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is String) return json['error'] as String;
    } catch (_) {
      // Fall through to a generic message.
    }
    return 'The studio service rejected the sync.';
  }
}
