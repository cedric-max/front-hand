import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class GamePage extends StatefulWidget {
  final String serverAddress;

  const GamePage({Key? key, required this.serverAddress}) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late IO.Socket socket;
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  void _connectToServer() {
    socket = IO.io(widget.serverAddress, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      print('Connected to server');
      setState(() {
        _messages.add('Connected to server');
      });
    });

    socket.on('message', (data) {
      setState(() {
        _messages.add('${data['clientName']}: ${data['text']}');
      });
    });

    socket.on('player_joined', (data) {
      setState(() {
        _messages.add('${data['name']} has joined the game');
      });
    });

    socket.on('player_left', (data) {
      setState(() {
        _messages.add('${data['name']} has left the game');
      });
    });

    socket.onDisconnect((_) {
      print('Disconnected from server');
      setState(() {
        _messages.add('Disconnected from server');
      });
    });

    socket.connect();
  }

  void _sendMessage(String message) {
    socket.emit('message', message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stable Hand Game'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _sendMessage('Player action');
                  },
                  child: const Text('Send Action'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GPSPage()),
                    );
                  },
                  child: const Text('Open GPS'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }
}

class GPSPage extends StatefulWidget {
  const GPSPage({Key? key}) : super(key: key);

  @override
  _GPSPageState createState() => _GPSPageState();
}

class _GPSPageState extends State<GPSPage> {
  Position? _currentPosition;
  String _locationMessage =
      "Appuyez sur le bouton pour obtenir la localisation";
  late StreamSubscription<Position> _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Les services de localisation sont désactivés.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = 'Les permissions de localisation sont refusées.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage =
            'Les permissions de localisation sont définitivement refusées.';
      });
      return;
    }

    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      setState(() {
        _currentPosition = position;
        _locationMessage =
            'Latitude: ${position.latitude}, Longitude: ${position.longitude}';

        if (position.speed < 0.1) {
          Vibration.vibrate();
        }
      });
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Informations GPS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              _locationMessage,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startLocationUpdates,
              child: const Text('Obtenir la localisation'),
            ),
            const SizedBox(height: 20),
            if (_currentPosition != null) ...[
              Text('Altitude: ${_currentPosition!.altitude} m'),
              Text('Vitesse: ${_currentPosition!.speed} m/s'),
              Text('Précision: ${_currentPosition!.accuracy} m'),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Retour au jeu'),
            ),
          ],
        ),
      ),
    );
  }
}
