import 'package:equatable/equatable.dart';
import '../../../../models/entities.dart';

sealed class GameState extends Equatable {
  const GameState();
  @override
  List<Object?> get props => [];
}

class GameInitial extends GameState {
  const GameInitial();
}

class GameLoading extends GameState {
  const GameLoading();
}

class GameRunning extends GameState {
  final GameStateEntity gameState;
  final String localPlayerId;
  const GameRunning({required this.gameState, required this.localPlayerId});
  @override
  List<Object?> get props => [gameState, localPlayerId];
}

class GameOver extends GameState {
  final GameResultEntity result;
  const GameOver(this.result);
  @override
  List<Object?> get props => [result];
}

class GameError extends GameState {
  final String message;
  const GameError(this.message);
  @override
  List<Object?> get props => [message];
}

