import 'package:equatable/equatable.dart';

enum PlayerRole { runner, guard }

class Vec2 extends Equatable {
  final double x;
  final double y;
  const Vec2(this.x, this.y);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  Vec2 lerp(Vec2 target, double t) =>
      Vec2(x + (target.x - x) * t, y + (target.y - y) * t);

  double distanceTo(Vec2 o) {
    final dx = x - o.x;
    final dy = y - o.y;
    return (dx * dx + dy * dy) == 0
        ? 0
        : (dx * dx + dy * dy) < 0
            ? 0
            : _sqrt(dx * dx + dy * dy);
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory Vec2.fromJson(Map<String, dynamic> j) =>
      Vec2((j['x'] as num).toDouble(), (j['y'] as num).toDouble());

  @override
  List<Object?> get props => [x, y];
}

class PlayerEntity extends Equatable {
  final String id;
  final PlayerRole role;
  final Vec2 position;
  final double angle;
  final int tagCount;
  final bool isVisible;

  const PlayerEntity({
    required this.id,
    required this.role,
    required this.position,
    this.angle = 0,
    this.tagCount = 0,
    this.isVisible = false,
  });

  PlayerEntity copyWith({
    Vec2? position,
    double? angle,
    int? tagCount,
    bool? isVisible,
  }) =>
      PlayerEntity(
        id: id,
        role: role,
        position: position ?? this.position,
        angle: angle ?? this.angle,
        tagCount: tagCount ?? this.tagCount,
        isVisible: isVisible ?? this.isVisible,
      );

  factory PlayerEntity.fromJson(Map<String, dynamic> j) => PlayerEntity(
        id: j['id'] as String,
        role: PlayerRole.values.byName(j['role'] as String),
        position: Vec2.fromJson(j['position'] as Map<String, dynamic>),
        angle: (j['angle'] as num? ?? 0).toDouble(),
        tagCount: j['tagCount'] as int? ?? 0,
        isVisible: j['isVisible'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'position': position.toJson(),
        'angle': angle,
        'tagCount': tagCount,
        'isVisible': isVisible,
      };

  @override
  List<Object?> get props => [id, role, position, angle, tagCount, isVisible];
}

class ArtifactEntity extends Equatable {
  final String id;
  final Vec2 position;
  final bool isCollected;
  final String? collectedBy;

  const ArtifactEntity({
    required this.id,
    required this.position,
    this.isCollected = false,
    this.collectedBy,
  });

  factory ArtifactEntity.fromJson(Map<String, dynamic> j) => ArtifactEntity(
        id: j['id'] as String,
        position: Vec2.fromJson(j['position'] as Map<String, dynamic>),
        isCollected: j['isCollected'] as bool? ?? false,
        collectedBy: j['collectedBy'] as String?,
      );

  @override
  List<Object?> get props => [id, position, isCollected, collectedBy];
}

enum GamePhase { lobby, playing, ended }

class GameStateEntity extends Equatable {
  final GamePhase phase;
  final Map<String, PlayerEntity> players;
  final List<ArtifactEntity> artifacts;
  final String? winner;
  final String? winReason;
  final int tick;
  final int secondsRemaining;

  const GameStateEntity({
    required this.phase,
    required this.players,
    required this.artifacts,
    this.winner,
    this.winReason,
    this.tick = 0,
    this.secondsRemaining = 180,
  });

  factory GameStateEntity.fromJson(Map<String, dynamic> j) => GameStateEntity(
        phase: GamePhase.values.byName(j['phase'] as String? ?? 'lobby'),
        players: (j['players'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, PlayerEntity.fromJson(v as Map<String, dynamic>)),
        ),
        artifacts: (j['artifacts'] as List<dynamic>? ?? [])
            .map((a) => ArtifactEntity.fromJson(a as Map<String, dynamic>))
            .toList(),
        winner: j['winner'] as String?,
        winReason: j['winReason'] as String?,
        tick: j['tick'] as int? ?? 0,
        secondsRemaining: j['secondsRemaining'] as int? ?? 180,
      );

  @override
  List<Object?> get props =>
      [phase, players, artifacts, winner, winReason, tick, secondsRemaining];
}

class GameResultEntity extends Equatable {
  final String winner;
  final String reason;
  final int secondsSurvived;
  final int artifactsCollected;
  final int tagsMade;

  const GameResultEntity({
    required this.winner,
    required this.reason,
    required this.secondsSurvived,
    required this.artifactsCollected,
    required this.tagsMade,
  });

  factory GameResultEntity.fromJson(Map<String, dynamic> j) => GameResultEntity(
        winner: j['winner'] as String,
        reason: j['reason'] as String,
        secondsSurvived: j['secondsSurvived'] as int? ?? 0,
        artifactsCollected: j['artifactsCollected'] as int? ?? 0,
        tagsMade: j['tagsMade'] as int? ?? 0,
      );

  @override
  List<Object?> get props =>
      [winner, reason, secondsSurvived, artifactsCollected, tagsMade];
}

class LobbyPlayerInfo extends Equatable {
  final String id;
  final PlayerRole role;
  const LobbyPlayerInfo({required this.id, required this.role});

  factory LobbyPlayerInfo.fromJson(Map<String, dynamic> j) => LobbyPlayerInfo(
        id: j['id'] as String,
        role: PlayerRole.values.byName(j['role'] as String),
      );

  @override
  List<Object?> get props => [id, role];
}

