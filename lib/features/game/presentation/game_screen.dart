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
      bloc: _bloc,
    );

    _bloc.add(GameStarted(playerId: widget.localPlayerId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<GameBloc, GameState>(
        // Only listen for navigation-level events — NOT GameRunning.
        // Game-state updates flow directly Flame ↔ stream, zero rebuilds.
        listenWhen: (_, s) => s is GameOver,
        listener: (context, state) {
          if (state is GameOver) {
            context.go('/result', extra: state.result);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (event) => _flameGame.onMouseMove(event.localPosition),
            child: Stack(
              children: [
                GameWidget(game: _flameGame),
                Positioned(
                  right: 24,
                  bottom: 120,
                  child: _ActionButtons(
                    role: widget.localRole,
                    onCollect: () => _bloc.sendCollectImmediate(),
                    onTag: () => _bloc.sendTagImmediate(),
                  ),
                ),
              ],
            ),
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

// ── Action buttons widget ─────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final PlayerRole role;
  final VoidCallback onCollect;
  final VoidCallback onTag;

  const _ActionButtons({
    required this.role,
    required this.onCollect,
    required this.onTag,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (role == PlayerRole.runner)
          _CircleButton(
            icon: Icons.star,
            label: 'COLLECT',
            color: const Color(0xFF00FFAA),
            onPressed: onCollect,
          ),
        if (role == PlayerRole.guard)
          _CircleButton(
            icon: Icons.pan_tool,
            label: 'TAG',
            color: const Color(0xFFE53935),
            onPressed: onTag,
          ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
