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
  World? _world;
  CameraComponent? _camera;

  // Server-state stream subscription (bypasses widget tree)
  StreamSubscription<GameStateEntity>? _stateSub;
  final Interpolator _interpolator = Interpolator();

  // Smooth camera target
  Vector2 _cameraTarget = Vector2.zero();
  static const double _cameraLerpSpeed = 8.0; // tiles/sec feel

  // Throttle: only send a move packet when the value actually changed
  double _lastDx = 0, _lastDy = 0, _lastAngle = 0;

  // Input smoothing — ramp toward target instead of instant 0/1
  double _smoothDx = 0, _smoothDy = 0;
  static const double _accel = 6.0;  // ramp-up speed (units/sec toward 1.0)
  static const double _decel = 8.0;  // ramp-down speed (units/sec toward 0.0)

  // Throttle sends to match server tick rate (~20Hz = 50ms)
  double _sendAccum = 0;
  static const double _sendInterval = 0.05; // seconds between input packets

  // Pending screen size for zoom — set if onGameResize fires before onLoad
  Vector2? _pendingSize;

  BountyDashGame({
    required this.localPlayerId,
    required this.localRole,
    required this.bloc,
  });

  @override
  Color backgroundColor() => const Color(0xFF1A1A26);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final cam = _camera;
    if (cam == null) {
      // onLoad hasn't run yet — stash the size and apply zoom later.
      _pendingSize = size.clone();
      return;
    }
    _applyZoom(cam, size);
  }

  void _applyZoom(CameraComponent cam, Vector2 size) {
    final tilesVisible = size.x < 700 ? 18.0 : 26.0;
    final desiredZoom = size.x / (tilesVisible * kTileSize);
    cam.viewfinder.zoom = desiredZoom.clamp(0.8, 3.0);
  }

  @override
  Future<void> onLoad() async {
    final world = World();
    final camera = CameraComponent(world: world);
    _world = world;
    _camera = camera;
    addAll([world, camera]);

    world.add(MapComponent());

    _hud = HudComponent(
      localPlayerId: localPlayerId,
      localRole: localRole,
    );
    camera.viewport.add(_hud);

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
      camera.viewport.add(_joystick!);
    }

    // Apply pending zoom if onGameResize fired before onLoad
    if (_pendingSize != null) {
      _applyZoom(camera, _pendingSize!);
      _pendingSize = null;
    }

    // Subscribe to server state stream DIRECTLY inside Flame —
    // zero widget-tree rebuilds per server tick.
    _stateSub = bloc.gameStateStream.listen(_onServerState);
  }

  void _onServerState(GameStateEntity state) {
    _interpolator.onNewState(state);
    final world = _world;
    if (world == null) return;

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
          world.add(c);
        }
      } else {
        if (_guards.containsKey(p.id)) {
          _guards[p.id]!.updateEntity(p);
        } else {
          final c =
              GuardComponent(entity: p, isLocalPlayer: p.id == localPlayerId);
          _guards[p.id] = c;
          world.add(c);
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
        world.add(c);
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
    final cam = _camera;
    if (cam != null) {
      final current = cam.viewfinder.position;
      cam.viewfinder.position = current +
          (_cameraTarget - current) * (_cameraLerpSpeed * dt).clamp(0.0, 1.0);
    }

    // ── Read raw input target ────────────────────────────────────────────────
    double targetDx = 0, targetDy = 0;

    if (_joystick != null) {
      // delta is in pixels; background radius = 60 → gives clean -1..1 range.
      targetDx = (_joystick!.delta.x / 60).clamp(-1.0, 1.0);
      targetDy = (_joystick!.delta.y / 60).clamp(-1.0, 1.0);
    } else {
      if (_keysDown.contains(LogicalKeyboardKey.keyW) ||
          _keysDown.contains(LogicalKeyboardKey.arrowUp)) { targetDy = -1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyS) ||
          _keysDown.contains(LogicalKeyboardKey.arrowDown)) { targetDy = 1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyA) ||
          _keysDown.contains(LogicalKeyboardKey.arrowLeft)) { targetDx = -1; }
      if (_keysDown.contains(LogicalKeyboardKey.keyD) ||
          _keysDown.contains(LogicalKeyboardKey.arrowRight)) { targetDx = 1; }

      if (_keysDown.contains(LogicalKeyboardKey.space)) {
        if (localRole == PlayerRole.guard) { bloc.sendTagImmediate(); }
        if (localRole == PlayerRole.runner) { bloc.sendCollectImmediate(); }
      }
    }

    // ── Smooth ramp toward target (acceleration / deceleration) ────────────
    _smoothDx = _ramp(_smoothDx, targetDx, dt);
    _smoothDy = _ramp(_smoothDy, targetDy, dt);

    // Update facing angle from smoothed direction
    if (_smoothDx.abs() > 0.05 || _smoothDy.abs() > 0.05) {
      _facingAngle = math.atan2(_smoothDy, _smoothDx);
    }

    // ── Throttle sends to server tick rate (20Hz) ──────────────────────────
    _sendAccum += dt;
    if (_sendAccum >= _sendInterval) {
      _sendAccum -= _sendInterval;

      final dx = _smoothDx;
      final dy = _smoothDy;
      final isMoving = dx.abs() > 0.02 || dy.abs() > 0.02;
      final angleChanged = (localRole == PlayerRole.guard) &&
          (_facingAngle - _lastAngle).abs() > 0.01;

      if (isMoving || angleChanged) {
        bloc.sendMoveImmediate(dx: dx, dy: dy, angle: _facingAngle);
        _lastDx = dx;
        _lastDy = dy;
        _lastAngle = _facingAngle;
      } else if (_lastDx != 0 || _lastDy != 0) {
        // Send one final zero-input packet when the player stops moving.
        bloc.sendMoveImmediate(dx: 0, dy: 0, angle: _facingAngle);
        _lastDx = 0;
        _lastDy = 0;
      }
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
    final cam = _camera;
    if (localGuard == null || cam == null) return;
    final worldPos = cam.globalToLocal(screenPos.toVector2());
    final gPos = localGuard.position;
    _facingAngle = math.atan2(worldPos.y - gPos.y, worldPos.x - gPos.x);
  }

  // ── Tap passthrough ───────────────────────────────────────────────────────
  @override
  void onTapDown(TapDownEvent event) {}

  /// Smoothly ramp [current] toward [target] using acceleration/deceleration.
  double _ramp(double current, double target, double dt) {
    if ((target - current).abs() < 0.01) return target;
    final rate = target.abs() >= current.abs() ? _accel : _decel;
    if (current < target) {
      return (current + rate * dt).clamp(current, target);
    } else {
      return (current - rate * dt).clamp(target, current);
    }
  }

  @override
  void onDetach() {
    _stateSub?.cancel();
    super.onDetach();
  }
}

extension on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}

