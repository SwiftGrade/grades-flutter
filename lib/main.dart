import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grade_core/grade_core.dart';
import 'package:grades/screens/academic_info_screen.dart';
import 'package:grades/screens/course_grades/course_grades_screen.dart';
import 'package:grades/screens/grade_info_screen.dart';
import 'package:grades/screens/home_screen/home_screen.dart';
import 'package:grades/screens/login/login_screen.dart';
import 'package:grades/screens/settings_screen.dart';
import 'package:grades/screens/sis_webview.dart';
import 'package:grades/screens/splash_screen.dart';
import 'package:grades/simple_bloc_delegate.dart';
import 'package:grades/widgets/offline_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BlocSupervisor.delegate = SimpleBlocDelegate();

  var package_info = await getPackageInfo();
  // Used for sentry error reporting and settings page version number
  GRADES_VERSION = '${package_info.version}+${package_info.buildNumber}';

  var offlineBloc = OfflineBloc();
  var prefs = await SharedPreferences.getInstance();
  var dataPersistence = DataPersistence(prefs);
  var sisRepository = SISRepository(offlineBloc, dataPersistence);

  var secureStorage = WrappedSecureStorage();
  var username = await secureStorage.read(key: AuthConst.SIS_USERNAME_KEY);
  var password = await secureStorage.read(key: AuthConst.SIS_PASSWORD_KEY);

  runApp(MultiRepositoryProvider(
    providers: [
      RepositoryProvider(create: (_) => dataPersistence),
      RepositoryProvider(create: (_) => sisRepository)
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthenticationBloc(
            sisRepository: sisRepository,
            offlineBloc: offlineBloc,
          )..add(AppStarted()),
        ),
        BlocProvider(
          create: (_) => SettingsBloc(
            initialStateSource: () {
              try {
                var settings = serializers.deserializeWith(
                  SettingsState.serializer,
                  jsonDecode(prefs.getString('settings')),
                );
                return settings;
              } catch (_) {
                return SettingsState.defaultSettings();
              }
            },
            stateSaver: (settings) {
              prefs.setString(
                'settings',
                jsonEncode(
                  serializers.serializeWith(SettingsState.serializer, settings),
                ),
              );
            },
          ),
        ),
        BlocProvider(
          create: (_) => ThemeBloc(
            initialStateSource: () {
              var themeStr = prefs.getString('theme');
              return ThemeModeExt.fromString(themeStr) ?? ThemeMode.system;
            },
            stateSaver: (theme) {
              prefs.setString('theme', theme.toPrefsString());
            },
          ),
        ),
        BlocProvider(
          create: (_) => offlineBloc,
        ),
      ],
      child: App(
        sisRepository: sisRepository,
        username: username,
        password: password,
      ),
    ),
  ));
}

class App extends StatelessWidget {
  final SISRepository _sisRepository;
  final String username;
  final String password;

  App(
      {@required SISRepository sisRepository,
      @required this.username,
      @required this.password})
      : assert(sisRepository != null),
        _sisRepository = sisRepository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeMode>(
      builder: (context, ThemeMode themeMode) {
        return MaterialApp(
          title: 'SwiftGrade',
          theme: ThemeData(
            primaryColor: const Color(0xff2a84d2),
            scaffoldBackgroundColor: const Color(0xff2a84d2),
            accentColor: const Color(0xff216bac),
            cardColor: const Color(0xffffffff),
            primaryColorLight: Colors.black,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primaryColor: const Color(0xff195080),
            scaffoldBackgroundColor: const Color(0xff195080),
            accentColor: const Color(0xff216bac),
            cardColor: const Color(0xff226baa),
            primaryColorLight: Colors.white,
            brightness: Brightness.dark,
          ),
          themeMode: themeMode,
          builder: (context, child) {
            return Column(
              children: [
                Expanded(child: child),
                BlocBuilder<OfflineBloc, OfflineState>(
                  builder: (context, offlineState) {
                    if (offlineState.offline) {
                      return OfflineBar();
                    } else {
                      return Container();
                    }
                  },
                ),
              ],
            );
          },
          routes: {
            '/course_grades': (_) => CourseGradesScreen(),
            '/grade_info': (_) => GradeInfoScreen(),
            '/settings': (_) => SettingsScreen(),
            '/academic_info': (_) => BlocProvider(
                  create: (context) =>
                      AcademicInfoBloc(sisRepository: _sisRepository)
                        ..add(FetchNetworkData()),
                  child: AcademicInfoScreen(),
                ),
            '/sis_webview': (_) => SISWebview(username, password),
          },
          home: AppRoot(),
        );
      },
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, AuthenticationState state) {
        if (state is Uninitialized) {
          return SplashScreen();
        } else if (state is Unauthenticated) {
          return LoginScreen();
        } else if (state is Authenticated) {
          return HomeScreen();
        }
        return null;
      },
    );
  }
}
