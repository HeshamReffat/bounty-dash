import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../domain/use_cases/game_use_cases.dart';
import '../../../../models/entities.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  final WatchGameStateUseCase _watchState;
  final WatchGameResultUseCase _watchResult;
  final SendMoveUseCase _sendMove;
  final AttemptTagUseCase _attemptTag;
  final CollectArtifactUseCase _collectArtifact;

  StreamSubscription? _resultSub;

  /// Expose the raw game-state stream so Flame can subscribe directly,
  /// bypassing BLoC/widget-tree rebuilds entirely for the render path.
  Stream<GameStateEntity> get gameStateStream => _watchState();

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
    on<GameResultReceived>(_onGameResultReceived);
    on<ArtifactCollectRequested>(_onCollect);
    on<TagAttempted>(_onTag);
    on<GameStopped>(_onGameStopped);
  }

  void _onGameStarted(GameStarted event, Emitter<GameState> emit) {
    emit(const GameLoading());

    // Only subscribe to game-OVER results here — game state updates go
    // directly to Flame without touching the BLoC state machine.
    _resultSub = _watchResult().listen(
      (r) => add(GameResultReceived(r)),
    );
  }

  void _onGameResultReceived(
      GameResultReceived event, Emitter<GameState> emit) {
    emit(GameOver(event.result));
  }

  // Input handlers — bypass BLoC event queue and call use-cases directly
  // to avoid the extra async hop on every frame.
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
    _resultSub?.cancel();
    emit(const GameInitial());
  }

  /// Call from BountyDashGame to send moves without going through the BLoC
  /// event queue — eliminates the async hop on every Flame update tick.
  void sendMoveImmediate(
      {required double dx, required double dy, required double angle}) {
    _sendMove(dx: dx, dy: dy, angle: angle);
  }

  void sendTagImmediate() => _attemptTag();
  void sendCollectImmediate() => _collectArtifact();

  @override
  Future<void> close() {
    _resultSub?.cancel();
    return super.close();
  }
}

