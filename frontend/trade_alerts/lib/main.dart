import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Trade Alert Data Model
class TradeAlert {
  final String underlying;
  final String day;
  final String month;
  final String year;
  final String strike;
  final String opt;
  final String entryLow;
  final String entryHigh;
  final String stoploss;
  final List<double> targets;
  final String instrumentToken;
  final String tradingSymbol;
  final String exchange;
  final String tradeId;
  final String title;
  final String entry;

  TradeAlert({
    required this.underlying,
    required this.day,
    required this.month,
    required this.year,
    required this.strike,
    required this.opt,
    required this.entryLow,
    required this.entryHigh,
    required this.stoploss,
    required this.targets,
    required this.instrumentToken,
    required this.tradingSymbol,
    required this.exchange,
    required this.tradeId,
    required this.title,
    required this.entry,
  });

  factory TradeAlert.fromJson(Map<String, dynamic> json) {
    List<double> parseTargets(dynamic targetsData) {
      if (targetsData == null) return [];
      if (targetsData is String) {
        try {
          final decoded = jsonDecode(targetsData);
          return List<double>.from(decoded);
        } catch (e) {
          print('Error parsing targets: $e');
          return [];
        }
      }
      if (targetsData is List) {
        return List<double>.from(targetsData);
      }
      return [];
    }

    return TradeAlert(
      underlying: json['underlying'] ?? '',
      day: json['day'] ?? '',
      month: json['month'] ?? '',
      year: json['year'] ?? '',
      strike: json['strike'] ?? '',
      opt: json['opt'] ?? '',
      entryLow: json['entry_low'] ?? '',
      entryHigh: json['entry_high'] ?? '',
      stoploss: json['stoploss'] ?? '',
      targets: parseTargets(json['targets']),
      instrumentToken: json['instrument_token'] ?? '',
      tradingSymbol: json['tradingsymbol'] ?? '',
      exchange: json['exchange'] ?? '',
      tradeId: json['trade_id'] ?? '',
      title: json['title'] ?? '',
      entry: json['entry'] ?? '',
    );
  }
}

// Firebase background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const TradeAlertApp());
}

class TradeAlertApp extends StatelessWidget {
  const TradeAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trade Alerts',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TradeAlertHomePage(),
    );
  }
}

class TradeAlertHomePage extends StatefulWidget {
  const TradeAlertHomePage({super.key});

  @override
  State<TradeAlertHomePage> createState() => _TradeAlertHomePageState();
}

class _TradeAlertHomePageState extends State<TradeAlertHomePage> {
  final TextEditingController _lotsController = TextEditingController();
  TradeAlert? _currentTradeAlert;
  bool _isLoading = false;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      }

      // Get FCM token
      _fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token: $_fcmToken');

      // Subscribe to the 'trades' topic
      await FirebaseMessaging.instance.subscribeToTopic('trades');
      print('Subscribed to trades topic');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print(
            'Message also contained a notification: ${message.notification}',
          );
          _showNotificationDialog(message);
        }

        // Show trade confirmation dialog for new trade alerts
        if (message.data.isNotEmpty) {
          _showTradeConfirmationDialog(message.data);
        }
      });

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        if (message.data.isNotEmpty) {
          _showTradeConfirmationDialog(message.data);
        }
      });
    } catch (e) {
      print('Error initializing Firebase: $e');
      _showErrorDialog('Failed to initialize Firebase: $e');
    }
  }

  void _showTradeConfirmationDialog(Map<String, dynamic> data) {
    try {
      final tradeAlert = TradeAlert.fromJson(data);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return TradeConfirmationDialog(tradeAlert: tradeAlert);
        },
      );
    } catch (e) {
      print('Error parsing trade alert: $e');
      _showErrorDialog('Error parsing trade alert: $e');
    }
  }

  void _showNotificationDialog(RemoteMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message.notification?.title ?? 'New Trade Alert'),
          content: Text(
            message.notification?.body ?? 'You have a new trade alert',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _placeTrade() async {
    if (_currentTradeAlert == null) {
      _showErrorDialog('No trade alert available');
      return;
    }

    if (_lotsController.text.isEmpty) {
      _showErrorDialog('Please enter number of lots');
      return;
    }

    int lots;
    try {
      lots = int.parse(_lotsController.text);
      if (lots <= 0) {
        _showErrorDialog('Number of lots must be greater than 0');
        return;
      }
    } catch (e) {
      _showErrorDialog('Please enter a valid number for lots');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.42.204.215:8000/order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'trade_id': _currentTradeAlert!.tradeId,
          'lots': lots,
          'side': 'BUY',
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog('Trade placed successfully!');
        _lotsController.clear();
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorDialog(
          'Failed to place trade: ${errorData['detail'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _skipTrade() {
    setState(() {
      _currentTradeAlert = null;
      _lotsController.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trade skipped')));
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Trade Alerts'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _currentTradeAlert == null
            ? _buildWaitingView()
            : _buildTradeAlertView(),
      ),
    );
  }

  Widget _buildWaitingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Waiting for trade alerts...',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'You will receive notifications when new trades are available',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeAlertView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest Trade Alert',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTradeDetailRow('Title', _currentTradeAlert!.title),
                  _buildTradeDetailRow(
                    'Underlying',
                    _currentTradeAlert!.underlying,
                  ),
                  _buildTradeDetailRow(
                    'Strike Price',
                    _currentTradeAlert!.strike,
                  ),
                  _buildTradeDetailRow('Option Type', _currentTradeAlert!.opt),
                  _buildTradeDetailRow(
                    'Expiry Date',
                    '${_currentTradeAlert!.day}/${_currentTradeAlert!.month}/${_currentTradeAlert!.year}',
                  ),
                  _buildTradeDetailRow(
                    'Entry Range',
                    '${_currentTradeAlert!.entryLow} - ${_currentTradeAlert!.entryHigh}',
                  ),
                  _buildTradeDetailRow(
                    'Stop Loss',
                    _currentTradeAlert!.stoploss,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Targets:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._currentTradeAlert!.targets.asMap().entries.map((entry) {
                    int index = entry.key;
                    double target = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                      child: Text('Target ${index + 1}: $target'),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trade Action',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lotsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Number of Lots',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _placeTrade,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.trending_up),
                          label: Text(
                            _isLoading ? 'Placing...' : 'Place Trade',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _skipTrade,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Skip'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lotsController.dispose();
    super.dispose();
  }
}

// Trade Confirmation Dialog Widget
class TradeConfirmationDialog extends StatefulWidget {
  final TradeAlert tradeAlert;

  const TradeConfirmationDialog({super.key, required this.tradeAlert});

  @override
  State<TradeConfirmationDialog> createState() =>
      _TradeConfirmationDialogState();
}

class _TradeConfirmationDialogState extends State<TradeConfirmationDialog> {
  int _selectedLots = 1;
  bool _isLoading = false;

  Future<void> _confirmTrade() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.42.204.215:8000/order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'trade_id': widget.tradeAlert.tradeId,
          'lots': _selectedLots,
          'side': 'BUY',
          'stoploss': double.tryParse(widget.tradeAlert.stoploss)?.toInt() ?? 0,
          'target': widget.tradeAlert.targets.isNotEmpty 
              ? widget.tradeAlert.targets.first.toInt() 
              : 0,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorDialog(
          'Failed to place order: ${errorData['detail'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      _showErrorDialog('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectTrade() async {
    // Simply dismiss the dialog for rejection
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trade rejected'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Trade Alert',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Underlying', widget.tradeAlert.underlying),
                    _buildDetailRow('Strike Price', widget.tradeAlert.strike),
                    _buildDetailRow('Option Type', widget.tradeAlert.opt),
                    _buildDetailRow(
                      'Expiry Date',
                      '${widget.tradeAlert.day}/${widget.tradeAlert.month}/${widget.tradeAlert.year}',
                    ),
                    _buildDetailRow(
                      'Entry Range',
                      '${widget.tradeAlert.entryLow} - ${widget.tradeAlert.entryHigh}',
                    ),
                    _buildDetailRow('Stop Loss', widget.tradeAlert.stoploss),
                    _buildDetailRow('Exchange', widget.tradeAlert.exchange),
                    _buildDetailRow(
                      'Trading Symbol',
                      widget.tradeAlert.tradingSymbol,
                    ),
                    _buildDetailRow('Trade ID', widget.tradeAlert.tradeId),

                    // Targets section
                    if (widget.tradeAlert.targets.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Targets:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...widget.tradeAlert.targets.asMap().entries.map((entry) {
                        int index = entry.key;
                        double target = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            bottom: 4.0,
                          ),
                          child: Text(
                            'Target ${index + 1}: $target',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 24),

                    // Lot Selection
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Number of Lots',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _selectedLots > 1
                                    ? () => setState(() => _selectedLots--)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_selectedLots',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _selectedLots < 10
                                    ? () => setState(() => _selectedLots++)
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _rejectTrade,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _confirmTrade,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isLoading ? 'Placing...' : 'Confirm & Place Order',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
