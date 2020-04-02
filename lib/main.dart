import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grades/blocs/offline/offline_bloc.dart';
import 'package:grades/repos/sis_repository.dart';
import 'package:grades/screens/academic_info_screen.dart';
import 'package:grades/screens/course_grades/course_grades_screen.dart';
import 'package:grades/screens/grade_info_screen.dart';
import 'package:grades/screens/home_screen/home_screen.dart';
import 'package:grades/screens/login/login_screen.dart';
import 'package:grades/screens/settings_screen.dart';
import 'package:grades/screens/splash_screen.dart';
import 'package:grades/simple_bloc_delegate.dart';

import 'blocs/authentication/authentication_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BlocSupervisor.delegate = SimpleBlocDelegate();

  var offlineBloc = OfflineBloc();
  var sisRepository = SISRepository(offlineBloc);
  runApp(MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) =>
            AuthenticationBloc(sisRepository: sisRepository)..add(AppStarted()),
      ),
      BlocProvider(
        create: (context) => offlineBloc,
      ),
    ],
    child: App(
      sisRepository: sisRepository,
    ),
  ));
}

class App extends StatelessWidget {
  final SISRepository _sisRepository;

  App({@required SISRepository sisRepository})
      : assert(sisRepository != null),
        _sisRepository = sisRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftGrade',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/course_grades': (context) => CourseGradesScreen(),
        '/grade_info': (context) => GradeInfoScreen(),
        '/settings': (context) => SettingsScreen(),
        '/academic_info': (context) => AcademicInfoScreen(),
      },
      home: AppRoot(sisRepository: _sisRepository),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({
    Key key,
    @required SISRepository sisRepository,
  })  : _sisRepository = sisRepository,
        super(key: key);

  final SISRepository _sisRepository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (BuildContext context, AuthenticationState state) {
        if (state is Uninitialized) {
          return SplashScreen();
        } else if (state is Unauthenticated) {
          return LoginScreen(
            sisRepository: _sisRepository,
          );
        } else if (state is Authenticated) {
          return HomeScreen(
            sisRepository: _sisRepository,
          );
        }
        return null;
      },
    );
  }
}
