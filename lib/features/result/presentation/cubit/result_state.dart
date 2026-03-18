import 'package:equatable/equatable.dart';
import '../../../../models/entities.dart';

sealed class ResultState extends Equatable {
  const ResultState();
  @override
  List<Object?> get props => [];
}

class ResultInitial extends ResultState {
  const ResultInitial();
}

class ResultLoaded extends ResultState {
  final GameResultEntity result;
  const ResultLoaded(this.result);
  @override
  List<Object?> get props => [result];
}

