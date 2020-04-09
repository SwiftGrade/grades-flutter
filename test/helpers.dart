import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grade_core/grade_core.dart';

void testNetworkBlocFetch<T>(Bloc bloc, bool Function(T) pred) async {
  await expectLater(
    bloc,
    emitsInOrder(
      <dynamic>[
        isA<NetworkLoading>(), // Initial state
        isA<NetworkLoading>(),
        predicate<T>(pred)
      ],
    ),
  );
}

void testNetworkBlocRefresh<T>(Bloc bloc, bool Function(T) pred) async {
  await expectLater(
    bloc,
    emitsInOrder(
      <dynamic>[
        isA<NetworkLoading>(), // Initial state
        predicate<T>(pred)
      ],
    ),
  );
}

void testNetworkBlocFetchError(Bloc bloc) async {
  await expectLater(
    bloc,
    emitsInOrder(
      <dynamic>[
        isA<NetworkLoading>(), // Initial state
        isA<NetworkLoading>(),
        isA<NetworkError>(),
      ],
    ),
  );
}

void testNetworkBlocRefreshError(Bloc bloc) async {
  await expectLater(
    bloc,
    emitsInOrder(
      <dynamic>[
        isA<NetworkLoading>(), // Initial state
        isA<NetworkError>(),
      ],
    ),
  );
}
