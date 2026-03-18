import 'package:equatable/equatable.dart';
import '../../../../models/entities.dart';

sealed class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class GameStarted extends GameEvent {
  final String playerId;
  const GameStarted({required this.playerId});
  @override
  List<Object?> get props => [playerId];
}

class GameStateReceived extends GameEvent {
  final GameStateEntity state;
  const GameStateReceived(this.state);
  @override
  List<Object?> get props => [state];
}

class GameResultReceived extends GameEvent {
  final GameResultEntity result;
  const GameResultReceived(this.result);
  @override
  List<Object?> get props => [result];
}

class PlayerMoved extends GameEvent {
  final double dx;
  final double dy;
  final double angle;
  const PlayerMoved({required this.dx, required this.dy, required this.angle});
  @override
  List<Object?> get props => [dx, dy, angle];
}

class GuardRotated extends GameEvent {
  final double angle;
  const GuardRotated(this.angle);
  @override
  List<Object?> get props => [angle];
}

class ArtifactCollectRequested extends GameEvent {
  const ArtifactCollectRequested();
}

class TagAttempted extends GameEvent {
  const TagAttempted();
}

class GameStopped extends GameEvent {
  const GameStopped();
}

