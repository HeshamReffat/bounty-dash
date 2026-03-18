import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// Listens for UDP broadcasts from a LAN server and emits discovered IPs.
class LanDiscovery {
  static const int kBroadcastPort = 41234;
  RawDatagramSocket? _socket;
  final _controller = StreamController<String>.broadcast();

  Stream<String> get serverIps => _controller.stream;

  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kBroadcastPort,
      );
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram == null) return;
          try {
            final msg = jsonDecode(
              String.fromCharCodes(datagram.data),
            ) as Map<String, dynamic>;
            if (msg['type'] == 'BOUNTYDASH_SERVER') {
              final ip = datagram.address.address;
              final port = msg['port'] as int;
              _controller.add('ws://$ip:$port/ws');
            }
          } catch (_) {}
        }
      });
    } catch (_) {
      // UDP not available on this platform/network — manual IP entry used instead
    }
  }

  void stop() {
    _socket?.close();
    _controller.close();
  }
}

