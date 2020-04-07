part of 'network_action_bloc.dart';

@immutable
abstract class NetworkActionState {
  const NetworkActionState();
}

class NetworkLoading extends NetworkActionState {
  const NetworkLoading();
}

class NetworkLoaded<D> extends NetworkActionState {
  final D data;

  const NetworkLoaded(this.data);

  @override
  String toString() {
    return 'NetworkLoaded{data: $data}';
  }
}

class NetworkError extends NetworkActionState {}
