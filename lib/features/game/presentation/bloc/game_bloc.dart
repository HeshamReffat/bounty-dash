import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../domain/use_cases/game_use_cases.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  final WatchGameStateUseCase _watchState;
  final WatchGameResultUseCase _watchResult;
  final SendMoveUseCase _sendMove;
  final AttemptTagUseCase _attemptTag;
  final CollectArtifactUseCase _collectArtifact;

  StreamSubscription? _stateSub;
  StreamSubscription? _resultSub;
  String _localPlayerId = '';

  GameBloc({
    required WatchGameStateUseCase watchState,
    required WatchGameResultUseCase watchResult,
    required SendMoveUseCase sendMove,
    required AttemptTagUseCase attemptTag,
    required CollectArtifactUseCase collectArtifact,
  })  : _watchState = watchState,
        _watchResult = watchResult,
        _sendMove = sendMove,
        _attemptTag = attemptTag,
        _collectArtifact = collectArtifact,
        super(const GameInitial()) {
    // High-frequency input events — drop if still processing
    on<PlayerMoved>(_onPlayerMoved, transformer: droppable());
    on<GuardRotated>(_onGuardRotated, transformer: droppable());

    // Standard events
    on<GameStarted>(_onGameStarted);
    on<GameStateReceived>(_onGameStateReceived);
    on<GameResultReceived>(_onGameResultReceived);
    on<ArtifactCollectRequested>(_onCollect);
    on<TagAttempted>(_onTag);
    on<GameStopped>(_onGameStopped);
  }

  void _onGameStarted(GameStarted event, Emitter<GameState> emit) {
    _localPlayerId = event.playerId;
    emit(const GameLoading());

    _stateSub = _watchState().listen(
      (s) => add(GameStateReceived(s)),
      onError: (e) => add(const GameStopped()),
    );
    _resultSub = _watchResult().listen(
      (r) => add(GameResultReceived(r)),
    );
  }

  void _onGameStateReceived(GameStateReceived event, Emitter<GameState> emit) {
    emit(GameRunning(
      gameState: event.state,
      localPlayerId: _localPlayerId,
    ));
  }

  void _onGameResultReceived(
      GameResultReceived event, Emitter<GameState> emit) {
    emit(GameOver(event.result));
  }

  void _onPlayerMoved(PlayerMoved event, Emitter<GameState> emit) {
    _sendMove(dx: event.dx, dy: event.dy, angle: event.angle);
  }

  void _onGuardRotated(GuardRotated event, Emitter<GameState> emit) {
    _sendMove(dx: 0, dy: 0, angle: event.angle);
  }

  void _onCollect(ArtifactCollectRequested event, Emitter<GameState> emit) {
    _collectArtifact();
  }

  void _onTag(TagAttempted event, Emitter<GameState> emit) {
    _attemptTag();
  }

  void _onGameStopped(GameStopped event, Emitter<GameState> emit) {
    _stateSub?.cancel();
    _resultSub?.cancel();
    emit(const GameInitial());
  }

  @override
  Future<void> close() {
    _stateSub?.cancel();
    _resultSub?.cancel();
    return super.close();
  }
}

