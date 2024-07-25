import 'package:flutter/material.dart';
import 'game_page.dart';

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
                'Enter the server address to start the game.',
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
              child: const Text('Enter Server Address'),
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
