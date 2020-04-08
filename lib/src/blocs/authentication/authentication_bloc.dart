import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repos/sis_repository.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final SharedPreferences prefs;
  final SISRepository _sisRepository;

  AuthenticationBloc(
      {@required SISRepository sisRepository, @required this.prefs})
      : assert(sisRepository != null),
        _sisRepository = sisRepository;

  @override
  AuthenticationState get initialState => Uninitialized();

  @override
  Stream<AuthenticationState> mapEventToState(
    AuthenticationEvent event,
  ) async* {
    if (event is AppStarted) {
      try {
        await _sisRepository.login(
          prefs.getString('sis_username'),
          prefs.getString('sis_password'),
          prefs.getString('sis_session'),
        );
        yield Authenticated();
      } catch (_) {
        yield Unauthenticated();
      }
    } else if (event is LoggedIn) {
      yield Authenticated();
    } else if (event is LoggedOut) {
      yield Unauthenticated();
    }
  }
}
