import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static const String _tokenKey = 'zerodha_access_token';
  static String get _baseUrl => dotenv.env['BACKEND_BASE_URL'] ?? 'http://10.42.204.215:8000';

  /// Save access token securely
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Get saved access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Clear saved access token (on logout or token expiry)
  static Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Check if user is authenticated (has valid token)
  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Make authenticated API request with automatic token handling
  static Future<http.Response> makeAuthenticatedRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    final token = await getAccessToken();
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?additionalHeaders,
    };

    // Add access token to headers if available
    if (token != null && token.isNotEmpty) {
      headers['access-token'] = token;
    }

    final uri = Uri.parse('$_baseUrl$endpoint');
    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    // Handle token expiration or unauthorized access
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _handleTokenExpiration(response);
    }

    return response;
  }

  /// Handle token expiration by clearing stored token
  static Future<void> _handleTokenExpiration(http.Response response) async {
    try {
      final responseBody = jsonDecode(response.body);
      final message = responseBody['detail'] ?? responseBody['message'] ?? '';
      
      // Check for token expiration indicators
      if (message.toLowerCase().contains('token') && 
          (message.toLowerCase().contains('expired') || 
           message.toLowerCase().contains('invalid') ||
           message.toLowerCase().contains('unauthorized'))) {
        await clearAccessToken();
      }
    } catch (e) {
      // If we can't parse the response, clear token on 401/403 anyway
      await clearAccessToken();
    }
  }

  /// Place trade order with automatic token handling
  static Future<ApiResult> placeOrder({
    required String tradeId,
    required int lots,
    required String side,
    required int stoploss,
    required int target,
  }) async {
    try {
      final response = await makeAuthenticatedRequest(
        endpoint: '/order',
        method: 'POST',
        body: {
          'trade_id': tradeId,
          'lots': lots,
          'side': side,
          'stoploss': stoploss,
          'target': target,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResult(
          success: true,
          message: data['message'] ?? 'Order placed successfully',
          data: data,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return ApiResult(
          success: false,
          message: 'Authentication required. Please login again.',
          requiresReauth: true,
        );
      } else {
        final errorData = jsonDecode(response.body);
        return ApiResult(
          success: false,
          message: errorData['detail'] ?? 'Failed to place order',
        );
      }
    } catch (e) {
      return ApiResult(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// Get user authentication status and token validity
  static Future<AuthStatus> getAuthStatus() async {
    final token = await getAccessToken();
    
    if (token == null || token.isEmpty) {
      return AuthStatus(isAuthenticated: false, needsLogin: true);
    }

    // Optionally validate token with backend
    try {
      final response = await makeAuthenticatedRequest(
        endpoint: '/auth/validate',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        return AuthStatus(isAuthenticated: true, needsLogin: false);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await clearAccessToken();
        return AuthStatus(isAuthenticated: false, needsLogin: true);
      }
    } catch (e) {
      // If validation fails, assume token is still valid but network issue
      return AuthStatus(isAuthenticated: true, needsLogin: false);
    }

    return AuthStatus(isAuthenticated: true, needsLogin: false);
  }
}

/// Result class for API operations
class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final bool requiresReauth;

  ApiResult({
    required this.success,
    required this.message,
    this.data,
    this.requiresReauth = false,
  });
}

/// Authentication status class
class AuthStatus {
  final bool isAuthenticated;
  final bool needsLogin;

  AuthStatus({
    required this.isAuthenticated,
    required this.needsLogin,
  });
}
