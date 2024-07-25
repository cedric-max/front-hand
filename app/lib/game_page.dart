import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';

class GamePage extends StatefulWidget {
  final String serverAddress;

  const GamePage({Key? key, required this.serverAddress}) : super(key: key);

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
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      setState(() {
        _gyroscopeData = {'x': event.x, 'y': event.y, 'z': event.z};
      });
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
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
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
    });

    socket.on('message', (data) {
      setState(() {
        _statusMessage = '${data['clientName']}: ${data['text']}';
      });
    });

    socket.on('start_game', (_) {
      setState(() {
        _statusMessage = 'Le jeu a commencé';
      });
    });

    socket.on('new_instruction', (data) {
      setState(() {
        _instruction = data['instruction'];
        _statusMessage = 'Suivez les instructions';
        _isStable = true;
      });
    });

    socket.on('player_moved', (data) {
      setState(() {
        _statusMessage = '${data['player']} a bougé !';
      });
    });

    socket.on('end_game', (_) {
      setState(() {
        _statusMessage = 'Le jeu est terminé';
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

  @override
  Widget build(BuildContext context) {
    double bubbleX =
        _accelerometerData['x']! * 20; // Scaling factor to adjust sensitivity
    double bubbleY = _accelerometerData['y']! * 20;

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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: TextStyle(
                      fontSize: 20,
                      color: _isStable ? Colors.green : Colors.red),
                  textAlign: TextAlign.center,
                ),
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
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _isStable ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 100 + bubbleX - 10,
                    top: 100 - bubbleY - 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
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
