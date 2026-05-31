import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/env.dart';
import 'server_message.dart';

/// Thin WebSocket client for the backend `/call` endpoint. Sends control
/// messages as JSON text and audio as binary frames; exposes a parsed stream of
/// [ServerMessage]s. Holds no secrets — only talks to the backend proxy.
class CallClient {
  CallClient({String? url}) : _url = url ?? Env.callWsUrl;

  final String _url;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final StreamController<ServerMessage> _messages =
      StreamController<ServerMessage>.broadcast();

  Stream<ServerMessage> get messages => _messages.stream;
  bool get isConnected => _channel != null;

  Future<void> connect() async {
    if (_channel != null) return;
    final channel = WebSocketChannel.connect(Uri.parse(_url));
    await channel.ready;
    _channel = channel;
    _sub = channel.stream.listen(
      (data) {
        if (data is String) {
          final msg = ServerMessage.parse(data);
          if (msg != null) _messages.add(msg);
        }
      },
      onError: (Object e) => _messages.add(ErrorEvent('socket', e.toString())),
      onDone: () => _messages.add(const StatusEvent(SessionState.stopped)),
    );
  }

  void start({
    int sampleRate = 16000,
    String encoding = 'linear16',
    String mode = 'live',
  }) {
    _send({
      'type': 'start',
      'sampleRate': sampleRate,
      'encoding': encoding,
      'mode': mode,
    });
  }

  void sendAudio(Uint8List pcm) {
    _channel?.sink.add(pcm);
  }

  void swapSpeakers() => _send({'type': 'swapSpeakers'});

  void stop() => _send({'type': 'stop'});

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    await _messages.close();
  }
}
