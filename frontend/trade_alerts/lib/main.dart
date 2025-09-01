import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Trade Status Enum
enum TradeStatus { pending, placed, rejected }

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
  final TradeStatus status;
  final DateTime timestamp;

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
    this.status = TradeStatus.pending,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

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

  // Copy with method for status updates
  TradeAlert copyWith({
    TradeStatus? status,
    DateTime? timestamp,
  }) {
    return TradeAlert(
      underlying: underlying,
      day: day,
      month: month,
      year: year,
      strike: strike,
      opt: opt,
      entryLow: entryLow,
      entryHigh: entryHigh,
      stoploss: stoploss,
      targets: targets,
      instrumentToken: instrumentToken,
      tradingSymbol: tradingSymbol,
      exchange: exchange,
      tradeId: tradeId,
      title: title,
      entry: entry,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
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
  List<TradeAlert> _tradeAlerts = [];
  bool _isLoading = false;
  final TextEditingController _lotsController = TextEditingController();

  // Getters for filtered trade lists
  List<TradeAlert> get pendingTrades => 
      _tradeAlerts.where((trade) => trade.status == TradeStatus.pending).toList();
  
  List<TradeAlert> get placedTrades => 
      _tradeAlerts.where((trade) => trade.status == TradeStatus.placed).toList();
  
  List<TradeAlert> get rejectedTrades => 
      _tradeAlerts.where((trade) => trade.status == TradeStatus.rejected).toList();
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

        // Add new trade alert to list
        if (message.data.isNotEmpty) {
          _addNewTradeAlert(message.data);
        }
      });

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        if (message.data.isNotEmpty) {
          _addNewTradeAlert(message.data);
        }
      });
    } catch (e) {
      print('Error initializing Firebase: $e');
      _showErrorDialog('Failed to initialize Firebase: $e');
    }
  }

  void _addNewTradeAlert(Map<String, dynamic> data) {
    try {
      final tradeAlert = TradeAlert.fromJson(data);
      setState(() {
        _tradeAlerts.insert(0, tradeAlert); // Add to beginning of list
      });
    } catch (e) {
      print('Error parsing trade alert: $e');
      _showErrorDialog('Error parsing trade alert: $e');
    }
  }

  void _updateTradeStatus(String tradeId, TradeStatus status) {
    setState(() {
      final index = _tradeAlerts.indexWhere((trade) => trade.tradeId == tradeId);
      if (index != -1) {
        _tradeAlerts[index] = _tradeAlerts[index].copyWith(status: status);
      }
    });
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

  Future<void> _placeTrade(TradeAlert trade, int lots) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.42.204.215:8000/order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'trade_id': trade.tradeId,
          'lots': lots,
          'side': 'BUY',
          'stoploss': double.tryParse(trade.stoploss)?.toInt() ?? 0,
          'target': trade.targets.isNotEmpty ? trade.targets.first.toInt() : 0,
        }),
      );

      if (response.statusCode == 200) {
        _updateTradeStatus(trade.tradeId, TradeStatus.placed);
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

  void _rejectTrade(TradeAlert trade) {
    _updateTradeStatus(trade.tradeId, TradeStatus.rejected);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trade rejected'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showLotSelectionDialog(TradeAlert trade) {
    int selectedLots = 1;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Lots'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('How many lots for ${trade.title}?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: selectedLots > 1
                            ? () => setState(() => selectedLots--)
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
                          '$selectedLots',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: selectedLots < 10
                            ? () => setState(() => selectedLots++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _placeTrade(trade, selectedLots);
                  },
                  child: const Text('Place Order'),
                ),
              ],
            );
          },
        );
      },
    );
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
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              _tradeAlerts.isEmpty 
                  ? 'Waiting for Trade Alerts' 
                  : 'Trade Alerts (${_tradeAlerts.length})',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Trade List
          Expanded(
            child: _tradeAlerts.isEmpty
                ? _buildEmptyState()
                : _buildTradeList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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

  Widget _buildTradeList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending Trades Section
        if (pendingTrades.isNotEmpty) ...[
          _buildSectionHeader('Pending Trades', Colors.orange, pendingTrades.length),
          ...pendingTrades.map((trade) => _buildTradeCard(trade)),
          const SizedBox(height: 16),
        ],
        
        // Placed Trades Section
        if (placedTrades.isNotEmpty) ...[
          _buildSectionHeader('Placed Orders', Colors.green, placedTrades.length),
          ...placedTrades.map((trade) => _buildTradeCard(trade)),
          const SizedBox(height: 16),
        ],
        
        // Rejected Trades Section
        if (rejectedTrades.isNotEmpty) ...[
          _buildSectionHeader('Rejected Trades', Colors.red, rejectedTrades.length),
          ...rejectedTrades.map((trade) => _buildTradeCard(trade)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeCard(TradeAlert trade) {
    Color statusColor;
    switch (trade.status) {
      case TradeStatus.pending:
        statusColor = Colors.orange;
        break;
      case TradeStatus.placed:
        statusColor = Colors.green;
        break;
      case TradeStatus.rejected:
        statusColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trade.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      trade.status.name.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Trade details
              _buildDetailRow('Underlying', trade.underlying),
              _buildDetailRow('Strike', trade.strike),
              _buildDetailRow('Option Type', trade.opt),
              _buildDetailRow('Entry Range', '${trade.entryLow} - ${trade.entryHigh}'),
              _buildDetailRow('Stop Loss', trade.stoploss),
              if (trade.targets.isNotEmpty)
                _buildDetailRow('Targets', trade.targets.map((t) => t.toString()).join(', ')),
              
              // Action buttons for pending trades
              if (trade.status == TradeStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectTrade(trade),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showLotSelectionDialog(trade),
                        icon: const Icon(Icons.trending_up, size: 18),
                        label: const Text('Place Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
