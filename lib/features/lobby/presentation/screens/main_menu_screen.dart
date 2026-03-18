import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // navigation

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / title
              const Text(
                '⚡',
                style: TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 8),
              const Text(
                'BOUNTY DASH',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00E5FF),
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Asymmetric Hide & Seek',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
              const SizedBox(height: 60),
              _MenuButton(
                label: 'Play',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF00E5FF),
                onTap: () => context.go('/lobby'),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                label: 'How to Play',
                icon: Icons.help_outline,
                color: Colors.white38,
                onTap: () => _showHowToPlay(context),
              ),
              const SizedBox(height: 60),
              const Text(
                'v1.0.0',
                style: TextStyle(color: Colors.white12, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('How to Play',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: const Text(
            '🏃 RUNNER:\n'
            '  • Collect all 3 artifacts\n'
            '  • Reach the gold exit zone\n'
            '  • Stay out of flashlight cones\n'
            '  • Standing still = invisible!\n\n'
            '🔦 GUARDS (×3):\n'
            '  • Shine your flashlight to reveal the Runner\n'
            '  • Tag the Runner twice to win\n'
            '  • Coordinate to cover all exits\n\n'
            'Controls:\n'
            '  WASD / Arrow keys = Move\n'
            '  Mouse = Aim flashlight\n'
            '  Space = Tag / Collect\n'
            '  Mobile: Left joystick = Move\n'
            '          Right tap = Action',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!',
                style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MenuButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

