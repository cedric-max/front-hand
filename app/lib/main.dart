import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stable Hand',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stable Hand'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to Stable Hand!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Hold your phone steady and follow the instructions to win!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GameSetupPage()),
                );
              },
              child: const Text('Start Game'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameSetupPage extends StatefulWidget {
  const GameSetupPage({Key? key}) : super(key: key);

  @override
  _GameSetupPageState createState() => _GameSetupPageState();
}

class _GameSetupPageState extends State<GameSetupPage> {
  final TextEditingController _serverAddressController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _serverAddressController,
              decoration: const InputDecoration(
                labelText: 'Enter Server Address',
                hintText: 'e.g., http://10.0.2.2:3000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final serverAddress = _serverAddressController.text;
                if (serverAddress.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GamePage(serverAddress: serverAddress),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a server address')),
                  );
                }
              },
              child: const Text('Connect to Server'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    super.dispose();
  }
}

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
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }
}
