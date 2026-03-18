import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// Broadcasts server presence on the LAN via UDP so clients can auto-discover.
class LanBroadcaster {
  static const int kBroadcastPort = 41234;
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start({required int wsPort}) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        try {
          final payload = jsonEncode({'type': 'BOUNTYDASH_SERVER', 'port': wsPort});
          _socket!.send(
            payload.codeUnits,
            InternetAddress('255.255.255.255'),
            kBroadcastPort,
          );
        } catch (_) {}
      });
      // ignore: avoid_print
      print('📡 LAN broadcaster started on UDP $kBroadcastPort');
    } catch (e) {
      // ignore: avoid_print
      print('📡 LAN broadcaster unavailable (UDP blocked): $e');
      // Server still works — clients must enter IP manually
    }
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
  }
}
