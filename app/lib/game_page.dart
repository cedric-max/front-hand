import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class GamePage extends StatefulWidget {
  final String serverAddress;
  final String playerName;

  const GamePage({
    Key? key,
    required this.serverAddress,
    required this.playerName,
  }) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late IO.Socket socket;
  late StreamSubscription _accelerometerSubscription;
  late StreamSubscription _gyroscopeSubscription;
  late StreamSubscription<Position> _positionStreamSubscription;
  Timer? _dataSendTimer;

  Map<String, double> _accelerometerData = {'x': 0.0, 'y': 0.0, 'z': 0.0};
  Map<String, double> _gyroscopeData = {'x': 0.0, 'y': 0.0, 'z': 0.0};
  Position? _currentPosition;
  String _instruction = 'Waiting for instructions...';
  String _statusMessage = 'Get Ready...';
  bool _isStable = false;
  bool _isInPosition = false;
  int _currentRound = 0;
  int _score = 0;
  bool _gameStarted = false;
  List<Map<String, dynamic>> _players = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
    _initializeSensorListeners();
    _initializeGPS();
  }

  void _initializeSensorListeners() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      setState(() {
        _accelerometerData = {'x': event.x, 'y': event.y, 'z': event.z};
      });
      _checkStabilityAndPosition();
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      setState(() {
        _gyroscopeData = {'x': event.x, 'y': event.y, 'z': event.z};
      });
      _checkStabilityAndPosition();
    });
  }

  void _initializeGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Location permissions are denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'Location permissions are permanently denied.';
      });
      return;
    }

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _checkMovement();
    });
  }

  void _connectToServer() {
    socket = IO.io(widget.serverAddress, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      setState(() {
        _statusMessage = 'Connected to server';
      });
      _startSendingData();
      socket.emit('join_game', {'playerName': widget.playerName});
    });

    socket.on('message', (data) {
      setState(() {
        _statusMessage = '${data['clientName']}: ${data['text']}';
      });
    });

    socket.on('start_game', (_) {
      setState(() {
        _gameStarted = true;
        _statusMessage = 'The game has started';
      });
    });

    socket.on('new_round', (data) {
      setState(() {
        _currentRound = data['round_actuel'];
        _instruction = data['position'];
        _players = List<Map<String, dynamic>>.from(data['joueurs']);
        _statusMessage = 'New Round: $_currentRound';
        _isStable = false;
        _isInPosition = false;
      });
    });

    socket.on('player_moved', (data) {
      setState(() {
        _statusMessage = '${data['player']} moved!';
      });
    });

    socket.on('end_game', (data) {
      setState(() {
        _gameStarted = false;
        _players = List<Map<String, dynamic>>.from(data['joueurs']);
        _statusMessage = 'The game is over';
        _showGameOverDialog(data['perdant']);
      });
    });

    socket.onDisconnect((_) {
      setState(() {
        _statusMessage = 'Disconnected from server';
      });
      _stopSendingData();
    });

    socket.connect();
  }

  void _startSendingData() {
    _dataSendTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_accelerometerData.isNotEmpty &&
          _gyroscopeData.isNotEmpty &&
          _currentPosition != null) {
        socket.emit('sensor_data', {
          'accelerometer': _accelerometerData,
          'gyroscope': _gyroscopeData,
          'gps': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
            'altitude': _currentPosition!.altitude,
            'speed': _currentPosition!.speed,
          }
        });
      }
    });
  }

  void _stopSendingData() {
    _dataSendTimer?.cancel();
  }

  void _checkStabilityAndPosition() {
    if (!_gameStarted) return;

    double accelerationMagnitude = sqrt(pow(_accelerometerData['x']!, 2) +
        pow(_accelerometerData['y']!, 2) +
        pow(_accelerometerData['z']!, 2));

    double gyroscopeMagnitude = sqrt(pow(_gyroscopeData['x']!, 2) +
        pow(_gyroscopeData['y']!, 2) +
        pow(_gyroscopeData['z']!, 2));

    // Increased tolerance for stability
    bool newIsStable = accelerationMagnitude < 11.0 && gyroscopeMagnitude < 0.2;

    // Improved orientation detection with increased tolerance
    bool newIsInPosition = false;
    if (_instruction == "verticale") {
      newIsInPosition = (_accelerometerData['z']!.abs() > 8.5 &&
          _accelerometerData['x']!.abs() < 1.5 &&
          _accelerometerData['y']!.abs() < 1.5);
    } else if (_instruction == "horizontale") {
      newIsInPosition = (_accelerometerData['y']!.abs() > 8.5 &&
          _accelerometerData['x']!.abs() < 1.5 &&
          _accelerometerData['z']!.abs() < 1.5);
    } else if (_instruction == "diagonale") {
      newIsInPosition = (_accelerometerData['x']!.abs() > 5.5 &&
          _accelerometerData['y']!.abs() > 5.5 &&
          _accelerometerData['z']!.abs() < 2.5);
    } else if (_instruction == "selfie") {
      newIsInPosition = (_accelerometerData['x']!.abs() > 7.5 &&
          _accelerometerData['y']!.abs() < 2.5 &&
          _accelerometerData['z']!.abs() < 2.5);
    }

    if (newIsStable != _isStable || newIsInPosition != _isInPosition) {
      setState(() {
        _isStable = newIsStable;
        _isInPosition = newIsInPosition;
      });

      if (!_isStable || !_isInPosition) {
        socket.emit(
            'player_moved', {'player': widget.playerName, 'stable': false});
      }
    }
  }

  void _checkMovement() {
    if (!_gameStarted || _currentPosition == null) return;

    if (_currentPosition!.speed > 0.5) {
      socket.emit('player_moved', {'player': widget.playerName, 'moved': true});
    }
  }

  void _showGameOverDialog(String perdant) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('The loser: $perdant'),
              const SizedBox(height: 10),
              Text('Scores:'),
              ..._players.map(
                  (player) => Text('${player['nom']}: ${player['score']}')),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to the welcome page
              },
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
        title: const Text('Stable Hand Game'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _instruction,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: TextStyle(
                      fontSize: 20,
                      color: _isStable && _isInPosition
                          ? Colors.green
                          : Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Round: $_currentRound',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Scores:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ..._players.map(
                    (player) => Text('${player['nom']}: ${player['score']}')),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: CustomPaint(
                size: Size(300, 300),
                painter: OrientationPainter(
                  accelerometerData: _accelerometerData,
                  instruction: _instruction,
                  isStable: _isStable,
                  isInPosition: _isInPosition,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    _positionStreamSubscription.cancel();
    socket.disconnect();
    socket.dispose();
    _stopSendingData();
    super.dispose();
  }
}

class OrientationPainter extends CustomPainter {
  final Map<String, double> accelerometerData;
  final String instruction;
  final bool isStable;
  final bool isInPosition;

  OrientationPainter({
    required this.accelerometerData,
    required this.instruction,
    required this.isStable,
    required this.isInPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw circle
    canvas.drawCircle(center, radius, paint);

    // Draw crosshair
    canvas.drawLine(Offset(center.dx - 10, center.dy),
        Offset(center.dx + 10, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 10),
        Offset(center.dx, center.dy + 10), paint);

    // Draw bubble
    final bubblePaint = Paint()
      ..color = isStable && isInPosition ? Colors.green : Colors.red
      ..style = PaintingStyle.fill;

    final bubbleRadius = 15.0;
    final bubbleX = center.dx + accelerometerData['x']! * (radius / 10);
    final bubbleY = center.dy - accelerometerData['y']! * (radius / 10);
    canvas.drawCircle(Offset(bubbleX, bubbleY), bubbleRadius, bubblePaint);

    // Draw target zone with increased tolerance
    final targetPaint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final toleranceWidth = size.width * 0.3; // Increased from 0.2
    final toleranceHeight = size.height * 0.3; // Increased from 0.2

    if (instruction == 'verticale') {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(center.dx, size.height * 0.1),
              width: toleranceWidth,
              height: toleranceHeight),
          targetPaint);
    } else if (instruction == 'horizontale') {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(size.width * 0.1, center.dy),
              width: toleranceWidth,
              height: toleranceHeight),
          targetPaint);
    } else if (instruction == 'diagonale') {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(size.width * 0.2, size.height * 0.2),
              width: toleranceWidth,
              height: toleranceHeight),
          targetPaint);
    } else if (instruction == 'selfie') {
      // Adjusted selfie position to be more intuitive
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(size.width * 0.8,
                  size.height * 0.2), // Changed from center.dx and 0.9
              width: toleranceWidth,
              height: toleranceHeight),
          targetPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
