import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/entities.dart';
import '../cubit/result_cubit.dart';
import '../cubit/result_state.dart';

class GameOverScreen extends StatelessWidget {
  final GameResultEntity result;
  const GameOverScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ResultCubit()..loadResult(result),
      child: const _GameOverView(),
    );
  }
}

class _GameOverView extends StatelessWidget {
  const _GameOverView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResultCubit, ResultState>(
      builder: (context, state) {
        if (state is! ResultLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final r = state.result;
        final isRunnerWin = r.winner == 'runner';

        return Scaffold(
          backgroundColor: const Color(0xFF12121E),
          body: SafeArea(
            child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isRunnerWin
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFFFF6B35),
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRunnerWin ? '🏃 RUNNER WINS!' : '🔦 GUARDS WIN!',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: isRunnerWin
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        r.reason,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 18),
                      ),
                      const SizedBox(height: 32),
                      _StatRow(
                          icon: '⏱',
                          label: 'Time Survived',
                          value: '${r.secondsSurvived}s'),
                      _StatRow(
                          icon: '💎',
                          label: 'Artifacts Collected',
                          value: '${r.artifactsCollected}/3'),
                      _StatRow(
                          icon: '🎯',
                          label: 'Tags Made',
                          value: '${r.tagsMade}/${r.maxTags}'),
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GameButton(
                            label: 'Play Again',
                            color: const Color(0xFF00E5FF),
                            onTap: () => context.go('/lobby'),
                          ),
                          const SizedBox(width: 20),
                          _GameButton(
                            label: 'Main Menu',
                            color: Colors.white24,
                            onTap: () => context.go('/'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String icon, label, value;
  const _StatRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$icon  ', style: const TextStyle(fontSize: 20)),
          SizedBox(
            width: 200,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GameButton(
      {required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}


