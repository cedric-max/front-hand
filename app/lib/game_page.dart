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
  String _instruction = 'En attente des instructions...';
  String _statusMessage = 'Préparez-vous...';
  bool _isStable = true;
  int _currentRound = 0;
  int _score = 0;
  bool _gameStarted = false;
  List<Map<String, dynamic>> _players = [];
  bool _isRoundActive = false;
  int _countdownValue = 5;

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
      _checkStability();
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      setState(() {
        _gyroscopeData = {'x': event.x, 'y': event.y, 'z': event.z};
      });
      _checkStability();
    });
  }

  void _initializeGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Les services de localisation sont désactivés.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Les permissions de localisation sont refusées.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage =
            'Les permissions de localisation sont définitivement refusées.';
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
        _statusMessage = 'Connecté au serveur';
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
        _statusMessage = 'Le jeu va commencer !';
      });
    });

    socket.on('countdown', (data) {
      setState(() {
        _countdownValue = data['count'];
        _statusMessage = 'La manche commence dans $_countdownValue secondes...';
        _isRoundActive = false;
      });
    });

    socket.on('new_round', (data) {
      setState(() {
        _currentRound = data['round_actuel'];
        _instruction = _getInstructionText(data['position']);
        _players = List<Map<String, dynamic>>.from(data['joueurs']);
        _statusMessage = 'Nouvelle manche: $_currentRound';
        _isStable = true;
        _isRoundActive = true;
      });
    });

    socket.on('player_moved', (data) {
      setState(() {
        _statusMessage = '${data['player']} a bougé !';
        _isRoundActive = false;
      });
    });

    socket.on('end_game', (data) {
      setState(() {
        _gameStarted = false;
        _players = List<Map<String, dynamic>>.from(data['joueurs']);
        _statusMessage = 'Le jeu est terminé';
        _showGameOverDialog(data['perdant']);
      });
    });

    socket.onDisconnect((_) {
      setState(() {
        _statusMessage = 'Déconnecté du serveur';
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

  void _checkStability() {
    if (!_gameStarted || !_isRoundActive) return;

    double accelerationMagnitude = sqrt(pow(_accelerometerData['x']!, 2) +
        pow(_accelerometerData['y']!, 2) +
        pow(_accelerometerData['z']!, 2));

    double gyroscopeMagnitude = sqrt(pow(_gyroscopeData['x']!, 2) +
        pow(_gyroscopeData['y']!, 2) +
        pow(_gyroscopeData['z']!, 2));

    bool newIsStable = accelerationMagnitude < 10.5 && gyroscopeMagnitude < 0.1;

    if (newIsStable != _isStable) {
      setState(() {
        _isStable = newIsStable;
      });

      if (!_isStable) {
        socket.emit(
            'player_moved', {'player': widget.playerName, 'stable': false});
      }
    }
  }

  void _checkMovement() {
    if (!_gameStarted || !_isRoundActive || _currentPosition == null) return;

    if (_currentPosition!.speed > 0.5) {
      socket.emit('player_moved', {'player': widget.playerName, 'moved': true});
    }
  }

  String _getInstructionText(String position) {
    switch (position) {
      case 'verticale':
        return 'Tenez votre téléphone verticalement !';
      case 'horizontale':
        return 'Tenez votre téléphone horizontalement !';
      case 'diagonale':
        return 'Tenez votre téléphone en diagonale !';
      case 'selfie':
        return 'Prenez la pose pour un selfie !';
      default:
        return 'Préparez-vous...';
    }
  }

  @override
  Widget build(BuildContext context) {
    double bubbleX = _accelerometerData['x']! * 10;
    double bubbleY = _accelerometerData['y']! * 10;

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
                      color: _isStable ? Colors.green : Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Manche: $_currentRound',
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                  if (_isRoundActive)
                    Positioned(
                      left: 100 + bubbleX,
                      top: 100 - bubbleY,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _isStable ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (!_isRoundActive)
                    Text(
                      '$_countdownValue',
                      style:
                          TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog(String perdant) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Fin de la partie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Le perdant: $perdant'),
              const SizedBox(height: 10),
              Text('Scores finaux:'),
              ..._players.map(
                  (player) => Text('${player['nom']}: ${player['score']}')),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Retour à la page d'accueil
              },
            ),
          ],
        );
      },
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
