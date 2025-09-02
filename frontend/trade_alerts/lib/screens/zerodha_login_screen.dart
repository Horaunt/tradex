import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import 'login_success_screen.dart';
import 'login_error_screen.dart';

class ZerodhaLoginScreen extends StatefulWidget {
  final String apiKey;
  final String redirectUrl;

  const ZerodhaLoginScreen({
    super.key,
    required this.apiKey,
    required this.redirectUrl,
  });

  @override
  State<ZerodhaLoginScreen> createState() => _ZerodhaLoginScreenState();
}

class _ZerodhaLoginScreenState extends State<ZerodhaLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final loginUrl = 'https://kite.trade/connect/login?api_key=${widget.apiKey}&v=3&redirect_url=${widget.redirectUrl}';
    
    // Debug logging
    print('Zerodha Login URL: $loginUrl');
    print('API Key: ${widget.apiKey} (${widget.apiKey.length} chars)');
    print('Redirect URL: ${widget.redirectUrl}');
    print('Note: Ensure redirect URL matches exactly in Kite Connect app configuration');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return _handleNavigation(request.url);
          },
        ),
      )
      ..loadRequest(Uri.parse(loginUrl));
  }

  NavigationDecision _handleNavigation(String url) {
    // Check if the URL matches our redirect URL
    if (url.startsWith(widget.redirectUrl)) {
      _extractTokenAndAuthenticate(url);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _extractTokenAndAuthenticate(String url) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final uri = Uri.parse(url);
      final requestToken = uri.queryParameters['request_token'];
      final status = uri.queryParameters['status'];

      if (requestToken != null && status == 'success') {
        // Send token to backend
        final result = await AuthService.authenticateWithZerodha(requestToken);
        
        if (mounted) {
          if (result.success) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoginSuccessScreen(
                  message: result.message,
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoginErrorScreen(
                  error: result.message,
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginErrorScreen(
                error: 'Login was cancelled or failed',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginErrorScreen(
              error: 'Error processing login: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zerodha Login'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1976D2),
              ),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processing authentication...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
