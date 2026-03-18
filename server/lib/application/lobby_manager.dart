import '../domain/entities/entities.dart';
import '../domain/map_data.dart';


class Room {
  final String code;
  final String hostId;
  final Map<String, PlayerEntity> players = {};
  bool started = false;

  Room({required this.code, required this.hostId});

  bool get isFull => players.length >= 4;
  bool get canStart => players.length >= 2 && !started;
}

/// Manages room lifecycle — application layer, no WebSocket I/O.
class LobbyManager {
  final Map<String, Room> _rooms = {};

  String createRoom(String hostId) {
    // 4-digit alphanumeric code
    final code = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    final role = PlayerRole.runner;
    final spawn = kSpawnPositions[0];
    final player = PlayerEntity(
      id: hostId,
      role: role,
      position: Vec2(spawn.col + 0.5, spawn.row + 0.5),
    );
    final room = Room(code: code, hostId: hostId);
    room.players[hostId] = player;
    _rooms[code] = room;
    return code;
  }

  /// Returns the room if joined successfully, null if full/not found.
  Room? joinRoom(String code, String playerId) {
    final room = _rooms[code];
    if (room == null || room.isFull || room.started) return null;
    final index = room.players.length;
    final spawn = kSpawnPositions[index.clamp(0, 3)];
    final player = PlayerEntity(
      id: playerId,
      role: PlayerRole.guard,
      position: Vec2(spawn.col + 0.5, spawn.row + 0.5),
    );
    room.players[playerId] = player;
    return room;
  }

  Room? getRoom(String code) => _rooms[code];

  Room? getRoomForPlayer(String playerId) {
    for (final room in _rooms.values) {
      if (room.players.containsKey(playerId)) return room;
    }
    return null;
  }

  void removePlayer(String playerId) {
    final room = getRoomForPlayer(playerId);
    if (room == null) return;
    room.players.remove(playerId);
    if (room.players.isEmpty) _rooms.remove(room.code);
  }

  List<Map<String, dynamic>> lobbySnapshot(Room room) => room.players.values
      .map((p) => {'id': p.id, 'role': p.role.name})
      .toList();
}

