import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // state management
import 'package:get_it/get_it.dart'; // dependency injection
import 'package:go_router/go_router.dart'; // routing
import '../../../../core/config/app_config.dart';
import '../../../../network/lan_discovery.dart';
import '../cubit/lobby_cubit.dart';
import '../cubit/lobby_state.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _codeCtrl = TextEditingController();
  final _ipCtrl = TextEditingController(text: 'localhost');
  final _lanDiscovery = LanDiscovery();
  final _discoveredIps = <String>[];

  @override
  void initState() {
    super.initState();
    _startLanDiscovery();
  }

  void _startLanDiscovery() async {
    try {
      await _lanDiscovery.start();
      _lanDiscovery.serverIps.listen((url) {
        if (!mounted) return;
        final ip = url.replaceFirst('ws://', '').split(':').first;
        if (!_discoveredIps.contains(ip)) {
          setState(() {
            _discoveredIps.add(ip);
            _ipCtrl.text = ip;
          });
        }
      });
    } catch (_) {
      // LAN discovery not available on this platform
    }
  }

  String get _serverUrl {
    final raw = _ipCtrl.text.trim();
    if (raw.isEmpty) return 'ws://localhost:8080/ws';

    // If user pasted a full URL (ws://, wss://, http://, https://), adapt it.
    if (raw.contains('://')) {
      if (raw.startsWith('ws://') || raw.startsWith('wss://')) {
        return raw.endsWith('/ws') ? raw : raw.replaceAll(RegExp(r'/+\$'), '') + (raw.endsWith('/ws') ? '' : '/ws');
      }
      // Convert http(s) to ws(s)
      if (raw.startsWith('http://')) {
        final hostOnly = raw.replaceFirst('http://', 'ws://');
        return hostOnly.endsWith('/ws') ? hostOnly : hostOnly + (hostOnly.endsWith('/') ? 'ws' : '/ws');
      }
      if (raw.startsWith('https://')) {
        final hostOnly = raw.replaceFirst('https://', 'wss://');
        return hostOnly.endsWith('/ws') ? hostOnly : hostOnly + (hostOnly.endsWith('/') ? 'ws' : '/ws');
      }
    }

    // Raw host input (no scheme). Heuristics:
    // - If looks like localhost or an IP, use ws://host:8080/ws (local dev)
    // - Otherwise assume a public hostname -> use wss://host/ws (production)
    final isLocalHost = raw == 'localhost' || raw == '127.0.0.1' || raw.startsWith('192.') || raw.startsWith('10.') || raw.startsWith('172.');
    final hasPort = raw.contains(':');
    if (isLocalHost) {
      return hasPort ? 'ws://$raw/ws' : 'ws://$raw:8080/ws';
    }

    // For public hostnames, prefer TLS WebSocket without a port
    return hasPort ? 'wss://$raw/ws' : 'wss://$raw/ws';
  }

  @override
  void dispose() {
    _lanDiscovery.stop();
    _codeCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: GetIt.I<LobbyCubit>(),
      child: BlocListener<LobbyCubit, LobbyState>(
        listener: (context, state) {
          if (state is LobbyWaiting) {
            context.go('/waiting');
          }
          if (state is LobbyFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF12121E),
          body: Center(
            child: SingleChildScrollView(
              child: BlocBuilder<LobbyCubit, LobbyState>(
                builder: (context, state) {
                  final isLoading =
                      state is LobbyConnecting || state is LobbyIdle;
                  return Container(
                    width: 420,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '⚡ BOUNTY DASH',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── LAN Server IP ──────────────────────────────────
                        const Text('Server IP',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _TextField(
                                  controller: _ipCtrl,
                                  hint: 'localhost or 192.168.x.x'),
                            ),
                            if (_discoveredIps.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: const Icon(Icons.wifi_find,
                                    color: Color(0xFF00FFAA)),
                              ),
                          ],
                        ),
                        if (_discoveredIps.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: _discoveredIps
                                .map((ip) => ActionChip(
                                      label: Text(ip,
                                          style: const TextStyle(
                                              fontSize: 11)),
                                      backgroundColor:
                                          const Color(0xFF00FFAA)
                                              .withValues(alpha: 0.15),
                                      onPressed: () => _ipCtrl.text = ip,
                                    ))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // ── Create Room ────────────────────────────────────
                        _ActionButton(
                          label: 'Create Room',
                          icon: Icons.add_circle_outline,
                          loading: isLoading,
                          color: const Color(0xFF00E5FF),
                          onTap: () async {
                            AppConfig.serverUrl = _serverUrl;
                            await context
                                .read<LobbyCubit>()
                                .connect(_serverUrl);
                            if (!context.mounted) return;
                            await context.read<LobbyCubit>().createRoom();
                          },
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 16),

                        // ── Join Room ──────────────────────────────────────
                        _TextField(
                          controller: _codeCtrl,
                          hint: 'Room Code (4 digits)',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        _ActionButton(
                          label: 'Join Room',
                          icon: Icons.login,
                          loading: isLoading,
                          color: const Color(0xFFFF6B35),
                          onTap: () async {
                            final code = _codeCtrl.text.trim();
                            if (code.isEmpty) return;
                            AppConfig.serverUrl = _serverUrl;
                            await context
                                .read<LobbyCubit>()
                                .connect(_serverUrl);
                            if (!context.mounted) return;
                            await context.read<LobbyCubit>().joinRoom(code);
                          },
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => context.go('/'),
                          child: const Text('← Back',
                              style: TextStyle(color: Colors.white38)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WaitingRoomScreen extends StatelessWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: GetIt.I<LobbyCubit>(),
      child: BlocListener<LobbyCubit, LobbyState>(
        listener: (context, state) {
          if (state is LobbyStarting) {
            final starting = state;
            final matched = starting.players.where((p) => p.id == starting.playerId).toList();
            final me = matched.isNotEmpty ? matched.first : null;
            // navigate to game, pass playerId and role
            context.go(
              '/game',
              extra: {
                'playerId': starting.playerId,
                'role': me?.role.name ?? 'guard',
              },
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF12121E),
          body: Center(
            child: BlocBuilder<LobbyCubit, LobbyState>(
              builder: (context, state) {
                if (state is! LobbyWaiting) {
                  return const CircularProgressIndicator(
                    // color: Color(0xFF00E5FF),
                  );
                }
                return Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Waiting Room',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Room: ${state.roomCode}',
                            style: const TextStyle(
                              fontSize: 22,
                              letterSpacing: 6,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ...state.players.map((p) => _PlayerTile(
                              playerId: p.id,
                              role: p.role.name,
                              isYou: p.id == state.playerId,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          '${state.players.length}/4 players',
                          style: const TextStyle(color: Colors.white38),
                        ),
                        const SizedBox(height: 24),
                        if (state.isHost)
                          _ActionButton(
                            label: state.canStart
                                ? 'Start Game'
                                : 'Need ≥ 2 players',
                            icon: Icons.play_arrow,
                            loading: false,
                            color: state.canStart
                                ? const Color(0xFF00FFAA)
                                : Colors.white24,
                            onTap: state.canStart
                                ? () => context.read<LobbyCubit>().startGame()
                                : null,
                          )
                        else
                          const Text(
                            'Waiting for host to start...',
                            style: TextStyle(color: Colors.white54),
                          ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.go('/lobby'),
                          child: const Text('← Leave',
                              style: TextStyle(color: Colors.white38)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final String playerId, role;
  final bool isYou;
  const _PlayerTile(
      {required this.playerId, required this.role, required this.isYou});

  @override
  Widget build(BuildContext context) {
    final isRunner = role == 'runner';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isRunner
            ? const Color(0xFF00E5FF).withValues(alpha: 0.1)
            : const Color(0xFFFF6B35).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: isYou
            ? Border.all(color: Colors.white38)
            : null,
      ),
      child: Row(
        children: [
          Text(isRunner ? '🏃' : '🔦',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isYou ? 'You (${role.toUpperCase()})' : role.toUpperCase(),
              style: TextStyle(
                color: isYou ? Colors.white : Colors.white70,
                fontWeight:
                    isYou ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isYou)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('YOU',
                  style: TextStyle(fontSize: 10, color: Colors.white54)),
            ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextAlign textAlign;
  const _TextField({
    required this.controller,
    required this.hint,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: textAlign,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.white12 : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: onTap == null ? Colors.white12 : color, width: 1.5),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                        color: onTap == null ? Colors.white38 : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}
