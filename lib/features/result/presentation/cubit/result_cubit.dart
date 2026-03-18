import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/entities.dart';
import '../../domain/use_cases/get_game_result_use_case.dart';
import 'result_state.dart';

class ResultCubit extends Cubit<ResultState> {
  final GetGameResultUseCase _getResult;

  ResultCubit({GetGameResultUseCase? getResult})
      : _getResult = getResult ?? const GetGameResultUseCase(),
        super(const ResultInitial());

  /// Called with a pre-parsed [GameResultEntity] (from GameBloc → GAME_OVER).
  void loadResult(GameResultEntity result) {
    // Run through the use-case so the domain layer owns the parsing contract.
    final validated = _getResult.call(result.toJson());
    emit(ResultLoaded(validated));
  }
}

