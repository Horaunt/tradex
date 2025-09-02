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
  TradeAlert copyWith({TradeStatus? status, DateTime? timestamp}) {
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
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
  List<TradeAlert> get pendingTrades => _tradeAlerts
      .where((trade) => trade.status == TradeStatus.pending)
      .toList();

  List<TradeAlert> get placedTrades => _tradeAlerts
      .where((trade) => trade.status == TradeStatus.placed)
      .toList();

  List<TradeAlert> get rejectedTrades => _tradeAlerts
      .where((trade) => trade.status == TradeStatus.rejected)
      .toList();
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
      final index = _tradeAlerts.indexWhere(
        (trade) => trade.tradeId == tradeId,
      );
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
        Uri.parse('http://172.16.204.18:8000/order'),
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.blue.shade50],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shopping_cart,
                            color: Color(0xFF1976D2),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Select Lot Size',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Trade info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            trade.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${trade.underlying} ${trade.strike} ${trade.opt}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Lot selector
                    const Text(
                      'Number of Lots',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF1976D2).withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: selectedLots > 1
                                ? () => setState(() => selectedLots--)
                                : null,
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: selectedLots > 1
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey,
                              size: 28,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$selectedLots',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: selectedLots < 10
                                ? () => setState(() => selectedLots++)
                                : null,
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: selectedLots < 10
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.grey),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _placeTrade(trade, selectedLots);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Place Order',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text(
              'Trade Alerts',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
      ),
      backgroundColor: Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            child: Text(
              _tradeAlerts.isEmpty
                  ? 'Waiting for Trade Alerts'
                  : 'Trade Alerts (${_tradeAlerts.length})',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.trending_up,
                size: 64,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Trade Alerts Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will receive notifications when new trades are available.\nMake sure notifications are enabled for this app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1976D2).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connected to trades topic',
                    style: TextStyle(
                      color: const Color(0xFF1976D2),
                      fontWeight: FontWeight.w500,
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

  Widget _buildTradeList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending Trades Section
        if (pendingTrades.isNotEmpty) ...[
          _buildSectionHeader(
            'Pending Trades',
            Colors.orange,
            pendingTrades.length,
          ),
          ...pendingTrades.map((trade) => _buildTradeCard(trade)),
          const SizedBox(height: 16),
        ],

        // Placed Trades Section
        if (placedTrades.isNotEmpty) ...[
          _buildSectionHeader(
            'Placed Orders',
            Colors.green,
            placedTrades.length,
          ),
          ...placedTrades.map((trade) => _buildTradeCard(trade)),
          const SizedBox(height: 16),
        ],

        // Rejected Trades Section
        if (rejectedTrades.isNotEmpty) ...[
          _buildSectionHeader(
            'Rejected Trades',
            Colors.red,
            rejectedTrades.length,
          ),
          ...rejectedTrades.map((trade) => _buildTradeCard(trade)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.2), width: 2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, statusColor.withOpacity(0.02)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
              _buildDetailRow(
                'Entry Range',
                '${trade.entryLow} - ${trade.entryHigh}',
              ),
              _buildDetailRow('Stop Loss', trade.stoploss),
              if (trade.targets.isNotEmpty)
                _buildDetailRow(
                  'Targets',
                  trade.targets.map((t) => t.toString()).join(', '),
                ),

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
