import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'models/accelerometer_data.dart';
import 'models/gyroscope_data.dart';

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

  AccelerometerData? _accelerometerData;
  GyroscopeData? _gyroscopeData;
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectToServer();
    _initializeSensorListeners();
  }

  void _initializeSensorListeners() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      setState(() {
        _accelerometerData =
            AccelerometerData(x: event.x, y: event.y, z: event.z);
      });
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      setState(() {
        _gyroscopeData = GyroscopeData(x: event.x, y: event.y, z: event.z);
      });
    });
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
            child: ListView(
              children: [
                if (_accelerometerData != null)
                  ListTile(
                    title:
                        Text('Accelerometer: ${_accelerometerData.toString()}'),
                  ),
                if (_gyroscopeData != null)
                  ListTile(
                    title: Text('Gyroscope: ${_gyroscopeData.toString()}'),
                  ),
                for (var message in _messages)
                  ListTile(
                    title: Text(message),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                _sendMessage('Player action');
              },
              child: const Text('Send Action'),
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
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }
}
