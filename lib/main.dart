// Versión mejorada: walkie-talkie con verificacion de conexión, control de turnos y transmisión

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:udp/udp.dart';

void main() => runApp(const WalkieTalkieApp());

class WalkieTalkieApp extends StatelessWidget {
  const WalkieTalkieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  late UDP _udp;
  bool _isRecording = false;
  bool _connected = false;
  bool _remoteIsTalking = false;
  TextEditingController ipController = TextEditingController(text: '192.168.0.102');
  int port = 5000;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (await Permission.microphone.request().isGranted) {
      await _recorder.openRecorder();
      await _player.openPlayer();
    }
    _udp = await UDP.bind(Endpoint.any(port: Port(port)));
    _listen();
    _sendPing();
  }

  void _sendPing() {
    _sendMessage("PING");
  }

  void _listen() async {
    _udp.asStream().listen((datagram) async {
      if (datagram == null) return;

      String message = utf8.decode(datagram.data);

      if (message == "PING") {
        _sendMessage("PONG");
        setState(() => _connected = true);
      } else if (message == "PONG") {
        setState(() => _connected = true);
      } else if (message == "TALKING") {
        setState(() => _remoteIsTalking = true);
      } else if (message == "IDLE") {
        setState(() => _remoteIsTalking = false);
      } else {
        await _player.startPlayer(fromDataBuffer: datagram.data);
      }
    });
  }

  void _sendMessage(String message) async {
    String destination = ipController.text.trim();
    if (destination.isNotEmpty) {
      await _udp.send(
        utf8.encode(message),
        Endpoint.unicast(InternetAddress(destination), port: Port(port)),
      );
    }
  }

  Future<void> _startRecording() async {
    _sendMessage("TALKING");
    await _recorder.startRecorder(toFile: 'audio.aac');
  }

  Future<void> _stopRecordingAndSend() async {
    String? path = await _recorder.stopRecorder();
    if (path == null) return;
    File audio = File(path);
    List<int> bytes = await audio.readAsBytes();
    _sendMessage("IDLE");

    String destination = ipController.text.trim();
    if (destination.isNotEmpty) {
      await _udp.send(
        bytes,
        Endpoint.unicast(InternetAddress(destination), port: Port(port)),
      );
    }
    audio.delete();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _udp.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = !_connected
        ? Colors.grey
        : _isRecording
        ? Colors.green
        : _remoteIsTalking
        ? Colors.blue.shade200
        : Colors.blue;

    return Scaffold(
      backgroundColor: statusColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'IP del otro dispositivo'),
              ),
            ),
            ElevatedButton(
              onPressed: (!_connected || _remoteIsTalking)
                  ? null
                  : () async {
                if (_isRecording) {
                  await _stopRecordingAndSend();
                  setState(() => _isRecording = false);
                } else {
                  await _startRecording();
                  setState(() => _isRecording = true);
                }
              },
              child: Text(_isRecording ? "Dejar de hablar" : "Hablar"),
            ),
            const SizedBox(height: 10),
            Text(
              !_connected
                  ? "Sin conexión"
                  : _remoteIsTalking
                  ? "El otro está hablando"
                  : _isRecording
                  ? "Estás hablando"
                  : "Conectado",
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

