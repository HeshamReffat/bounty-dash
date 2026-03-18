// ignore_for_file: avoid_relative_lib_imports
import 'dart:io';
import '../lib/infrastructure/game_server.dart';
import '../lib/infrastructure/lan_broadcaster.dart';

void main(List<String> args) async {
  // Respect the PORT environment variable (set by many PaaS providers, incl. Fly)
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  // Allow disabling LAN broadcaster in hosted environments where UDP broadcast
  // isn't supported or desired.
  final disableLan = (Platform.environment['DISABLE_LAN_BROADCAST'] ?? 'false').toLowerCase() == 'true';

  final broadcaster = LanBroadcaster();
  if (!disableLan) {
    await broadcaster.start(wsPort: port);
  } else {
    // ignore: avoid_print
    print('📡 LAN broadcaster disabled by DISABLE_LAN_BROADCAST=true');
  }

  await startServer(port: port);
}
