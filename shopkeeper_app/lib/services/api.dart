import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../models/repair.dart';

class ApiError implements Exception {
  final String message;
  final int status;
  ApiError(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api extends GetxService {
  final _pending = <String, String>{};
  Future<Json> call(String operation, [Json data = const {}]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiError('Please sign in.', 401);
    try {
      final token = await user.getIdToken();
      final response = await http
          .post(
            Uri.parse('${AppConfig.api}/owner/$operation'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 45));
      Json body;
      try {
        body = map(jsonDecode(utf8.decode(response.bodyBytes)));
      } catch (_) {
        throw ApiError(
          'Cannot reach the repair service. Retry when connected.',
        );
      }
      if (response.statusCode != 200) {
        throw ApiError(
          body['error']?.toString() ?? 'Request failed.',
          response.statusCode,
        );
      }
      return body;
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(
        'Save could not be confirmed. Reconnect and retry the same action.',
      );
    }
  }

  Future<Json> command(String operation, Json data) async {
    final key = '$operation:${jsonEncode(data)}';
    final id = _pending.putIfAbsent(key, () => const Uuid().v4());
    try {
      final result = await call(operation, {...data, 'requestId': id});
      _pending.remove(key);
      return result;
    } on ApiError catch (e) {
      if (e.status >= 400 && e.status < 500 && e.status != 429) {
        _pending.remove(key);
      }
      rethrow;
    }
  }

  void clear() => _pending.clear();
}
