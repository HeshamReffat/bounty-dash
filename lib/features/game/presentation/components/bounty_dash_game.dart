import 'dart:async';
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
import '../../../game/data/interpolator.dart';
import '../bloc/game_bloc.dart';
import 'map_component.dart';
import 'runner_component.dart';
import 'guard_component.dart';
import 'artifact_component.dart';
import 'hud_component.dart';

typedef OnAction = void Function();

class BountyDashGame extends FlameGame
    with KeyboardEvents, ScrollDetector, TapCallbacks {
  final String localPlayerId;
  final PlayerRole localRole;
  final GameBloc bloc;

  // Component registries
  final Map<String, RunnerComponent> _runners = {};
  final Map<String, GuardComponent> _guards = {};
  final Map<String, ArtifactComponent> _artifacts = {};
  late HudComponent _hud;
  JoystickComponent? _joystick;

  // Keyboard state
  final _keysDown = <LogicalKeyboardKey>{};
  double _facingAngle = 0;

  // World
  late final World _world;
  late final CameraComponent _camera;

  // Server-state stream subscription (bypasses widget tree)
  StreamSubscription<GameStateEntity>? _stateSub;
  final Interpolator _interpolator = Interpolator();

  // Smooth camera target
  Vector2 _cameraTarget = Vector2.zero();
  static const double _cameraLerpSpeed = 8.0; // tiles/sec feel

  // Throttle: only send a move packet when the value actually changed
  double _lastDx = 0, _lastDy = 0, _lastAngle = 0;

  BountyDashGame({
    required this.localPlayerId,
    required this.localRole,
    required this.bloc,
  });

  @override
  Color backgroundColor() => const Color(0xFF1A1A26);

  @override
  Future<void> onLoad() async {
    _world = World();
    _camera = CameraComponent.withFixedResolution(
      world: _world,
      width: 900,
      height: 600,
    );
    addAll([_world, _camera]);

    _world.add(MapComponent());

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
    }

    // Subscribe to server state stream DIRECTLY inside Flame —
    // zero widget-tree rebuilds per server tick.
    _stateSub = bloc.gameStateStream.listen(_onServerState);
  }

  void _onServerState(GameStateEntity state) {
    _interpolator.onNewState(state);

    // Update/add/remove components
    final currentIds = state.players.keys.toSet();

    for (final p in state.players.values) {
      if (p.role == PlayerRole.runner) {
        if (_runners.containsKey(p.id)) {
          _runners[p.id]!.updateEntity(p);
        } else {
          final c = RunnerComponent(
              entity: p, isLocalPlayer: p.id == localPlayerId);
          _runners[p.id] = c;
          _world.add(c);
        }
      } else {
        if (_guards.containsKey(p.id)) {
          _guards[p.id]!.updateEntity(p);
        } else {
          final c =
              GuardComponent(entity: p, isLocalPlayer: p.id == localPlayerId);
          _guards[p.id] = c;
          _world.add(c);
        }
      }
    }

    for (final id
        in _runners.keys.where((id) => !currentIds.contains(id)).toList()) {
      _runners.remove(id)?.removeFromParent();
    }
    for (final id
        in _guards.keys.where((id) => !currentIds.contains(id)).toList()) {
      _guards.remove(id)?.removeFromParent();
    }

    for (final a in state.artifacts) {
      if (_artifacts.containsKey(a.id)) {
        _artifacts[a.id]!.updateEntity(a);
      } else {
        final c = ArtifactComponent(entity: a);
        _artifacts[a.id] = c;
        _world.add(c);
      }
    }

    _hud.update_(state);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // ── Interpolate positions every frame ──────────────────────────────────
    final interp = _interpolator.tick(dt);
    if (interp != null) {
      for (final entry in interp.players.entries) {
        final p = entry.value;
        if (p.role == PlayerRole.runner) {
          _runners[entry.key]?.smoothPosition(p.position, dt);
        } else {
          _guards[entry.key]?.smoothPosition(p.position, dt);
        }
      }

      // ── Smooth camera follow ─────────────────────────────────────────
      final local = interp.players[localPlayerId];
      if (local != null) {
        _cameraTarget = Vector2(
          local.position.x * kTileSize,
          local.position.y * kTileSize,
        );
      }
    }

    // Lerp camera toward target (smooth follow, no snap)
    final current = _camera.viewfinder.position;
    _camera.viewfinder.position = current +
        (_cameraTarget - current) * (_cameraLerpSpeed * dt).clamp(0.0, 1.0);

    // ── Read input ─────────────────────────────────────────────────────────
    double dx = 0, dy = 0;
    bool forceMove = false; // true while joystick is actively held

    if (_joystick != null) {
      // delta is in pixels; background radius = 60 → gives clean -1..1 range.
      dx = (_joystick!.delta.x / 60).clamp(-1.0, 1.0);
      dy = (_joystick!.delta.y / 60).clamp(-1.0, 1.0);
      if (dx.abs() > 0.05 || dy.abs() > 0.05) {
        _facingAngle = math.atan2(dy, dx);
        forceMove = true; // always send while stick is deflected
      }
    } else {
      if (_keysDown.contains(LogicalKeyboardKey.keyW) ||
          _keysDown.contains(LogicalKeyboardKey.arrowUp)) { dy = -1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyS) ||
          _keysDown.contains(LogicalKeyboardKey.arrowDown)) { dy = 1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyA) ||
          _keysDown.contains(LogicalKeyboardKey.arrowLeft)) { dx = -1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyD) ||
          _keysDown.contains(LogicalKeyboardKey.arrowRight)) { dx = 1; }
      if (dx != 0 || dy != 0) forceMove = true;

      if (_keysDown.contains(LogicalKeyboardKey.space)) {
        if (localRole == PlayerRole.guard) bloc.sendTagImmediate();
        if (localRole == PlayerRole.runner) bloc.sendCollectImmediate();
      }
    }

    // Send every frame while moving (guarantees server gets continuous input).
    // For idle guards, throttle angle updates to avoid spamming.
    final angleChanged = (localRole == PlayerRole.guard) &&
        (_facingAngle - _lastAngle).abs() > 0.01;

    if (forceMove || angleChanged) {
      bloc.sendMoveImmediate(dx: dx, dy: dy, angle: _facingAngle);
      _lastDx = dx;
      _lastDy = dy;
      _lastAngle = _facingAngle;
    } else if (dx == 0 && dy == 0 && (_lastDx != 0 || _lastDy != 0)) {
      // Send one final zero-input packet when the player stops moving,
      // so the server knows to stop the entity.
      bloc.sendMoveImmediate(dx: 0, dy: 0, angle: _facingAngle);
      _lastDx = 0;
      _lastDy = 0;
    }
  }

  // ── Desktop keyboard ──────────────────────────────────────────────────────
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysDown
      ..clear()
      ..addAll(keysPressed);
    return KeyEventResult.handled;
  }

  // ── Mouse move → guard flashlight (desktop) ───────────────────────────────
  @override
  void onScroll(PointerScrollInfo info) {}

  void onMouseMove(Offset screenPos) {
    if (localRole != PlayerRole.guard) return;
    final localGuard = _guards[localPlayerId];
    if (localGuard == null) return;
    final worldPos = _camera.globalToLocal(screenPos.toVector2());
    final gPos = localGuard.position;
    _facingAngle = math.atan2(worldPos.y - gPos.y, worldPos.x - gPos.x);
  }

  // ── Tap passthrough ───────────────────────────────────────────────────────
  @override
  void onTapDown(TapDownEvent event) {}

  @override
  void onDetach() {
    _stateSub?.cancel();
    super.onDetach();
  }
}

extension on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}

