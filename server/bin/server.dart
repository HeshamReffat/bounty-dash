// ignore_for_file: avoid_relative_lib_imports
import '../lib/infrastructure/game_server.dart';
import '../lib/infrastructure/lan_broadcaster.dart';

void main(List<String> args) async {
  const port = 8080;
  final broadcaster = LanBroadcaster();
  await broadcaster.start(wsPort: port);
  await startServer(port: port);
}

