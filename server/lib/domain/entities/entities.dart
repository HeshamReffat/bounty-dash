enum PlayerRole { runner, guard }

class Vec2 {
  final double x;
  final double y;
  const Vec2(this.x, this.y);
  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  double distanceTo(Vec2 o) {
    final dx = x - o.x;
    final dy = y - o.y;
    return (dx * dx + dy * dy) == 0 ? 0 : (dx * dx + dy * dy) < 0 ? 0 : _sqrt(dx * dx + dy * dy);
  }
  static double _sqrt(double v) {
    // Newton's method — avoids dart:math import in pure domain
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 20; i++) { x = (x + v / x) / 2; }
    return x;
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory Vec2.fromJson(Map<String, dynamic> j) =>
      Vec2((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
  @override
  String toString() => 'Vec2($x,$y)';
}

class PlayerEntity {
  final String id;
  final PlayerRole role;
  final Vec2 position;
  final double angle; // radians, direction facing
  final int tagCount;
  final bool isVisible; // server-computed per recipient

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'position': position.toJson(),
        'angle': angle,
        'tagCount': tagCount,
        'isVisible': isVisible,
      };

  factory PlayerEntity.fromJson(Map<String, dynamic> j) => PlayerEntity(
        id: j['id'] as String,
        role: PlayerRole.values.byName(j['role'] as String),
        position: Vec2.fromJson(j['position'] as Map<String, dynamic>),
        angle: (j['angle'] as num).toDouble(),
        tagCount: j['tagCount'] as int,
        isVisible: j['isVisible'] as bool,
      );
}

class ArtifactEntity {
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

  ArtifactEntity copyWith({bool? isCollected, String? collectedBy}) =>
      ArtifactEntity(
        id: id,
        position: position,
        isCollected: isCollected ?? this.isCollected,
        collectedBy: collectedBy ?? this.collectedBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position.toJson(),
        'isCollected': isCollected,
        'collectedBy': collectedBy,
      };

  factory ArtifactEntity.fromJson(Map<String, dynamic> j) => ArtifactEntity(
        id: j['id'] as String,
        position: Vec2.fromJson(j['position'] as Map<String, dynamic>),
        isCollected: j['isCollected'] as bool,
        collectedBy: j['collectedBy'] as String?,
      );
}

enum GamePhase { lobby, playing, ended }

class GameStateEntity {
  final GamePhase phase;
  final Map<String, PlayerEntity> players;
  final List<ArtifactEntity> artifacts;
  final String? winner; // 'runner' | 'guards'
  final String? winReason;
  final int tick;
  final int secondsRemaining;
  final int maxTags;

  const GameStateEntity({
    required this.phase,
    required this.players,
    required this.artifacts,
    this.winner,
    this.winReason,
    this.tick = 0,
    this.secondsRemaining = 180,
    this.maxTags = 2,
  });

  GameStateEntity copyWith({
    GamePhase? phase,
    Map<String, PlayerEntity>? players,
    List<ArtifactEntity>? artifacts,
    String? winner,
    String? winReason,
    int? tick,
    int? secondsRemaining,
    int? maxTags,
  }) =>
      GameStateEntity(
        phase: phase ?? this.phase,
        players: players ?? this.players,
        artifacts: artifacts ?? this.artifacts,
        winner: winner ?? this.winner,
        winReason: winReason ?? this.winReason,
        tick: tick ?? this.tick,
        secondsRemaining: secondsRemaining ?? this.secondsRemaining,
        maxTags: maxTags ?? this.maxTags,
      );

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'players': players.map((k, v) => MapEntry(k, v.toJson())),
        'artifacts': artifacts.map((a) => a.toJson()).toList(),
        'winner': winner,
        'winReason': winReason,
        'tick': tick,
        'secondsRemaining': secondsRemaining,
        'maxTags': maxTags,
      };
}

class GameResultEntity {
  final String winner;
  final String reason;
  final int secondsSurvived;
  final int artifactsCollected;
  final int totalArtifacts;
  final int tagsMade;
  final int maxTags;

  const GameResultEntity({
    required this.winner,
    required this.reason,
    required this.secondsSurvived,
    required this.artifactsCollected,
    required this.tagsMade,
    this.totalArtifacts = 3,
    this.maxTags = 2,
  });

  Map<String, dynamic> toJson() => {
        'winner': winner,
        'reason': reason,
        'secondsSurvived': secondsSurvived,
        'artifactsCollected': artifactsCollected,
        'totalArtifacts': totalArtifacts,
        'tagsMade': tagsMade,
        'maxTags': maxTags,
      };

  factory GameResultEntity.fromJson(Map<String, dynamic> j) => GameResultEntity(
        winner: j['winner'] as String,
        reason: j['reason'] as String,
        secondsSurvived: j['secondsSurvived'] as int,
        artifactsCollected: j['artifactsCollected'] as int,
        totalArtifacts: j['totalArtifacts'] as int? ?? 3,
        tagsMade: j['tagsMade'] as int,
        maxTags: j['maxTags'] as int? ?? 2,
      );
}

