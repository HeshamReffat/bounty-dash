import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'bloc/game_bloc.dart';
import 'bloc/game_event.dart';
import 'bloc/game_state.dart';
import '../../../models/entities.dart';
import 'components/bounty_dash_game.dart';

class GameScreen extends StatefulWidget {
  final String localPlayerId;
  final PlayerRole localRole;

  const GameScreen({
    super.key,
    required this.localPlayerId,
    required this.localRole,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BountyDashGame _flameGame;
  late final GameBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I<GameBloc>();

    _flameGame = BountyDashGame(
      localPlayerId: widget.localPlayerId,
      localRole: widget.localRole,
      onMove: ({required dx, required dy, required angle}) =>
          _bloc.add(PlayerMoved(dx: dx, dy: dy, angle: angle)),
      onTag: () => _bloc.add(const TagAttempted()),
      onCollect: () => _bloc.add(const ArtifactCollectRequested()),
    );

    _bloc.add(GameStarted(playerId: widget.localPlayerId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<GameBloc, GameState>(
        listener: (context, state) {
          if (state is GameOver) {
            context.go('/result', extra: state.result);
          }
          if (state is GameRunning) {
            _flameGame.applyState(state.gameState);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (event) => _flameGame.onMouseMove(event.localPosition),
            child: GameWidget(game: _flameGame),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bloc.add(const GameStopped());
    super.dispose();
  }
}


