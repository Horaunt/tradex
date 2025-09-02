import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';

class AuthService {
  static String get _baseUrl => dotenv.env['BACKEND_BASE_URL'] ?? 'http://10.42.204.215:8000';
  
  /// Sends the request token to backend for Zerodha authentication
  static Future<AuthResult> authenticateWithZerodha(String requestToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/zerodha/auth'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'request_token': requestToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        
        // Save access token securely for future API calls
        if (accessToken != null && accessToken.isNotEmpty) {
          await ApiService.saveAccessToken(accessToken);
        }
        
        return AuthResult(
          success: true,
          message: data['message'] ?? 'Authentication successful',
          accessToken: accessToken,
        );
      } else if (response.statusCode == 404) {
        return AuthResult(
          success: false,
          message: 'Backend endpoint not found. Please implement /api/zerodha/auth endpoint.',
        );
      } else {
        final errorData = jsonDecode(response.body);
        return AuthResult(
          success: false,
          message: errorData['detail'] ?? 'Authentication failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// Logout user by clearing stored access token
  static Future<void> logout() async {
    await ApiService.clearAccessToken();
  }

  /// Check if user is currently authenticated
  static Future<bool> isLoggedIn() async {
    return await ApiService.isAuthenticated();
  }
}

class AuthResult {
  final bool success;
  final String message;
  final String? accessToken;

  AuthResult({
    required this.success,
    required this.message,
    this.accessToken,
  });
}
