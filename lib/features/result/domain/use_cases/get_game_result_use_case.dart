import '../../../../models/entities.dart';

/// Parses a raw result map (from GAME_OVER WS message) into a [GameResultEntity].
/// Keeps the result feature's domain self-contained — presentation never
/// touches JSON directly.
class GetGameResultUseCase {
  const GetGameResultUseCase();

  GameResultEntity call(Map<String, dynamic> raw) =>
      GameResultEntity.fromJson(raw);
}

