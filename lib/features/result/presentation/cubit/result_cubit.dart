import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/entities.dart';
import 'result_state.dart';

class ResultCubit extends Cubit<ResultState> {
  ResultCubit() : super(const ResultInitial());

  void loadResult(GameResultEntity result) => emit(ResultLoaded(result));
}

