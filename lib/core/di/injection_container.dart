import 'package:get_it/get_it.dart';
import '../../network/ws_client.dart';
import '../../features/lobby/data/lobby_repository_impl.dart';
import '../../features/lobby/domain/repositories/lobby_repository.dart';
import '../../features/lobby/domain/use_cases/lobby_use_cases.dart';
import '../../features/lobby/presentation/cubit/lobby_cubit.dart';
import '../../features/game/data/game_repository_impl.dart';
import '../../features/game/domain/repositories/game_repository.dart';
import '../../features/game/domain/use_cases/game_use_cases.dart';
import '../../features/game/presentation/bloc/game_bloc.dart';

final GetIt sl = GetIt.instance;

void setupDependencies() {
  // ── Infrastructure ──────────────────────────────────────────────────────
  sl.registerLazySingleton<WsClient>(() => WsClient());

  // ── Lobby feature ───────────────────────────────────────────────────────
  sl.registerLazySingleton<LobbyRepository>(
    () => LobbyRepositoryImpl(sl<WsClient>()) as LobbyRepository,
  );
  sl.registerLazySingleton(() => ConnectToServerUseCase(sl<LobbyRepository>()));
  sl.registerLazySingleton(() => CreateRoomUseCase(sl<LobbyRepository>()));
  sl.registerLazySingleton(() => JoinRoomUseCase(sl<LobbyRepository>()));
  sl.registerLazySingleton(() => StartGameUseCase(sl<LobbyRepository>()));

  sl.registerLazySingleton<LobbyCubit>(
    () => LobbyCubit(
      connectUseCase: sl<ConnectToServerUseCase>(),
      createRoom: sl<CreateRoomUseCase>(),
      joinRoom: sl<JoinRoomUseCase>(),
      startGame: sl<StartGameUseCase>(),
      repo: sl<LobbyRepository>(),
    ),
  );

  // ── Game feature ────────────────────────────────────────────────────────
  sl.registerLazySingleton<GameRepository>(
    () => GameRepositoryImpl(sl<WsClient>()),
  );
  sl.registerLazySingleton(() => WatchGameStateUseCase(sl<GameRepository>()));
  sl.registerLazySingleton(() => WatchGameResultUseCase(sl<GameRepository>()));
  sl.registerLazySingleton(() => SendMoveUseCase(sl<GameRepository>()));
  sl.registerLazySingleton(() => SendRotateUseCase(sl<GameRepository>()));
  sl.registerLazySingleton(() => AttemptTagUseCase(sl<GameRepository>()));
  sl.registerLazySingleton(() => CollectArtifactUseCase(sl<GameRepository>()));

  sl.registerFactory<GameBloc>(
    () => GameBloc(
      watchState: sl<WatchGameStateUseCase>(),
      watchResult: sl<WatchGameResultUseCase>(),
      sendMove: sl<SendMoveUseCase>(),
      attemptTag: sl<AttemptTagUseCase>(),
      collectArtifact: sl<CollectArtifactUseCase>(),
    ),
  );
}


