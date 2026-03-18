import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Route;
import '../../../../models/entities.dart';
import '../../../game/domain/map_data.dart';
import 'map_component.dart';
import 'runner_component.dart';
import 'guard_component.dart';
import 'artifact_component.dart';
import 'hud_component.dart';

/// Callback invoked when the local player produces an input action.
typedef OnPlayerInput = void Function({
  required double dx,
  required double dy,
  required double angle,
});
typedef OnAction = void Function();

class BountyDashGame extends FlameGame
    with KeyboardEvents, ScrollDetector, TapCallbacks {
  final String localPlayerId;
  final PlayerRole localRole;
  final OnPlayerInput onMove;
  final OnAction onTag;
  final OnAction onCollect;

  // Component registries
  final Map<String, RunnerComponent> _runners = {};
  final Map<String, GuardComponent> _guards = {};
  final Map<String, ArtifactComponent> _artifacts = {};
  late HudComponent _hud;
  late JoystickComponent? _joystick;

  // Keyboard state
  final _keysDown = <LogicalKeyboardKey>{};
  double _facingAngle = 0;

  // World
  late final World _world;
  late final CameraComponent _camera;

  BountyDashGame({
    required this.localPlayerId,
    required this.localRole,
    required this.onMove,
    required this.onTag,
    required this.onCollect,
  });

  @override
  Color backgroundColor() => const Color(0xFF1A1A26);

  @override
  Future<void> onLoad() async {
    // Fixed logical viewport 900×600
    _world = World();
    _camera = CameraComponent.withFixedResolution(
      world: _world,
      width: 900,
      height: 600,
    );
    addAll([_world, _camera]);

    _world.add(MapComponent());

    // HUD lives in the camera's viewport (overlay)
    _hud = HudComponent(
      localPlayerId: localPlayerId,
      localRole: localRole,
    );
    _camera.viewport.add(_hud);

    // Mobile joystick
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      _joystick = JoystickComponent(
        knob: CircleComponent(
          radius: 20,
          paint: Paint()..color = const Color(0x88FFFFFF),
        ),
        background: CircleComponent(
          radius: 60,
          paint: Paint()..color = const Color(0x44FFFFFF),
        ),
        margin: const EdgeInsets.only(left: 40, bottom: 40),
      );
      _camera.viewport.add(_joystick!);
    } else {
      _joystick = null;
    }
  }

  /// Called by GameScreen every time the Bloc emits a new GameRunning state.
  void applyState(GameStateEntity state) {
    final currentRunners =
        state.players.values.where((p) => p.role == PlayerRole.runner);
    final currentGuards =
        state.players.values.where((p) => p.role == PlayerRole.guard);

    // Update / add runners
    for (final p in currentRunners) {
      if (_runners.containsKey(p.id)) {
        _runners[p.id]!.update_(p);
      } else {
        final c = RunnerComponent(
          entity: p,
          isLocalPlayer: p.id == localPlayerId,
        );
        _runners[p.id] = c;
        _world.add(c);
      }
    }

    // Update / add guards
    for (final p in currentGuards) {
      if (_guards.containsKey(p.id)) {
        _guards[p.id]!.update_(p);
      } else {
        final c = GuardComponent(
          entity: p,
          isLocalPlayer: p.id == localPlayerId,
        );
        _guards[p.id] = c;
        _world.add(c);
      }
    }

    // Remove departed players
    for (final id in _runners.keys
        .where((id) => !state.players.containsKey(id))
        .toList()) {
      _runners.remove(id)?.removeFromParent();
    }
    for (final id in _guards.keys
        .where((id) => !state.players.containsKey(id))
        .toList()) {
      _guards.remove(id)?.removeFromParent();
    }

    // Update / add artifacts
    for (final a in state.artifacts) {
      if (_artifacts.containsKey(a.id)) {
        _artifacts[a.id]!.update_(a);
      } else {
        final c = ArtifactComponent(entity: a);
        _artifacts[a.id] = c;
        _world.add(c);
      }
    }

    // Follow local player
    final localPlayer = state.players[localPlayerId];
    if (localPlayer != null) {
      _camera.moveTo(Vector2(
        localPlayer.position.x * kTileSize,
        localPlayer.position.y * kTileSize,
      ));
    }

    _hud.update_(state);
  }

  // ── Desktop keyboard input ────────────────────────────────────────────────
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysDown.clear();
    _keysDown.addAll(keysPressed);
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);

    double dx = 0, dy = 0;

    if (_joystick != null) {
      // Mobile: read joystick
      dx = _joystick!.delta.x / 60;
      dy = _joystick!.delta.y / 60;
      if (dx.abs() > 0.01 || dy.abs() > 0.01) {
        _facingAngle = math.atan2(dy, dx);
      }
    } else {
      // Desktop: WASD
      if (_keysDown.contains(LogicalKeyboardKey.keyW) ||
          _keysDown.contains(LogicalKeyboardKey.arrowUp)) { dy = -1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyS) ||
          _keysDown.contains(LogicalKeyboardKey.arrowDown)) { dy = 1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyA) ||
          _keysDown.contains(LogicalKeyboardKey.arrowLeft)) { dx = -1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyD) ||
          _keysDown.contains(LogicalKeyboardKey.arrowRight)) { dx = 1; }

      // Space = tag / collect
      if (_keysDown.contains(LogicalKeyboardKey.space)) {
        if (localRole == PlayerRole.guard) onTag();
        if (localRole == PlayerRole.runner) onCollect();
      }
    }

    if (dx.abs() > 0.01 || dy.abs() > 0.01) {
      onMove(dx: dx, dy: dy, angle: _facingAngle);
    }
  }

  // ── Mouse move → guard flashlight rotation (desktop) ─────────────────────
  @override
  void onScroll(PointerScrollInfo info) {} // suppress scroll zoom

  void onMouseMove(Offset screenPos) {
    if (localRole != PlayerRole.guard) return;
    // Convert screen position to world angle relative to local guard
    final localGuard = _guards[localPlayerId];
    if (localGuard == null) return;
    final worldPos = _camera.globalToLocal(screenPos.toVector2());
    final guardScreenPos = localGuard.position;
    final dx = worldPos.x - guardScreenPos.x;
    final dy = worldPos.y - guardScreenPos.y;
    _facingAngle = math.atan2(dy, dx);
    onMove(dx: 0, dy: 0, angle: _facingAngle);
  }

  // ── Tap = action (mobile) ─────────────────────────────────────────────────
  @override
  void onTapDown(TapDownEvent event) {
    // Right half of screen = action button on mobile
    if (event.localPosition.x > 450) {
      if (localRole == PlayerRole.guard) onTag();
      if (localRole == PlayerRole.runner) onCollect();
    }
  }
}

extension on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}

