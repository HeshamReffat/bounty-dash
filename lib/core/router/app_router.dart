import 'package:go_router/go_router.dart';
import '../../features/lobby/presentation/screens/lobby_screens.dart';
import '../../features/lobby/presentation/screens/main_menu_screen.dart';
import '../../features/game/presentation/game_screen.dart';
import '../../features/result/presentation/screens/game_over_screen.dart';
import '../../models/entities.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (ctx, st) => const MainMenuScreen(),
    ),
    GoRoute(
      path: '/lobby',
      builder: (ctx, st) => const LobbyScreen(),
    ),
    GoRoute(
      path: '/waiting',
      builder: (ctx, st) => const WaitingRoomScreen(),
    ),
    GoRoute(
      path: '/game',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return GameScreen(
          localPlayerId: extra['playerId'] as String? ?? '',
          localRole: PlayerRole.values.byName(
            extra['role'] as String? ?? 'guard',
          ),
        );
      },
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        final result = state.extra as GameResultEntity? ??
            const GameResultEntity(
              winner: 'guards',
              reason: 'Unknown',
              secondsSurvived: 0,
              artifactsCollected: 0,
              tagsMade: 0,
            );
        return GameOverScreen(result: result);
      },
    ),
  ],
);
