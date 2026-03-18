import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Low-level WebSocket client. No business logic.
class WsClient {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _connected = false;

  Stream<Map<String, dynamic>> get messages => _controller.stream;
  bool get isConnected => _connected;

  Future<void> connect(String url) async {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    await _channel!.ready;
    _connected = true;
    _channel!.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(msg);
        } catch (_) {}
      },
      onDone: () {
        _connected = false;
        _controller.addError('disconnected');
      },
      onError: (e) {
        _connected = false;
        _controller.addError(e);
      },
    );
  }

  void send(Map<String, dynamic> msg) {
    if (!_connected) return;
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  void disconnect() {
    _connected = false;
    _channel?.sink.close();
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}

