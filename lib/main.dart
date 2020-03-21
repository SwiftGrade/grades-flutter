import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:grades/models/current_session.dart';
import 'package:grades/models/data_persistence.dart';
import 'package:grades/models/theme_controller.dart';
import 'package:grades/screens/academic_information_screen.dart';
import 'package:grades/screens/course_grades_screen.dart';
import 'package:grades/screens/course_list_screen.dart';
import 'package:grades/screens/feed_screen.dart';
import 'package:grades/screens/grade_item_detail_screen.dart';
import 'package:grades/screens/home_screen.dart';
import 'package:grades/screens/login_screen.dart';
import 'package:grades/screens/settings_screen.dart';
import 'package:grades/screens/splash_screen.dart';
import 'package:grades/screens/terms_screen.dart';
import 'package:grades/screens/terms_settings_screen.dart';
import 'package:grades/utilities/auth.dart';
import 'package:grades/utilities/package_info.dart';
import 'package:grades/utilities/sentry.dart';
import 'package:grades/utilities/wrapped_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // load the shared preferences from disk before the app is started
  final prefs = await SharedPreferences.getInstance();
  final package_info = await getPackageInfo();
  // Used for sentry error reporting and settings page version number
  version = '${package_info.version}+${package_info.buildNumber}';

  FlutterError.onError = (details, {bool forceReport = false}) {
    reportException(
      exception: details.exception,
      stackTrace: details.stack,
    );
    // Also use Flutter's pretty error logging to the device's console.
    FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
  };
  runZoned(
    () => runApp(MyApp(prefs: prefs)),
    onError: (Object error, StackTrace stackTrace) {
      reportException(
        exception: error,
        stackTrace: stackTrace,
      );
    },
  );
}

class MyApp extends StatelessWidget with PortraitModeMixin {
  // root of application.

  final SharedPreferences prefs;

  final GlobalKey<NavigatorState> _navKey = GlobalKey();

  MyApp({Key key, this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.renderView.automaticSystemUiAdjustment = false;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      // statusBarColor: Colors.white, //top bar color
      statusBarIconBrightness: Brightness.light, //top bar icons
      systemNavigationBarColor: Color(0xffebebeb),
      // Theme.of(context).primaryColor, //bottom bar color
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark, //bottom bar icons
    ));
    GLOBAL_DATA_PERSISTENCE = DataPersistence(prefs);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) =>
                CurrentSession(dataPersistence: GLOBAL_DATA_PERSISTENCE)),
        ChangeNotifierProvider(create: (_) => ThemeController(prefs)),
        ChangeNotifierProvider(create: (_) => GLOBAL_DATA_PERSISTENCE),
      ],
      child: Consumer<ThemeController>(
        builder: (BuildContext context, ThemeController theme, Widget child) {
          return Column(
            children: <Widget>[
              Expanded(
                child: MaterialApp(
                  navigatorKey: _navKey,
                  title: 'SwiftGrade',
                  debugShowCheckedModeBanner: false,
                  home: SplashScreen(),
                  theme: _buildCurrentTheme(theme),
                  routes: <String, WidgetBuilder>{
                    '/login': (BuildContext context) => LoginScreen(),
                    '/terms': (BuildContext context) => TermsScreen(),
                    '/terms_settings': (BuildContext context) =>
                        TermsSettingsScreen(),
                    '/settings': (BuildContext context) => SettingsScreen(),
                    '/courses': (BuildContext context) {
                      // Use a key here to prevent overlap in sessions
                      return CourseListScreen(
                          key: Provider.of<CurrentSession>(context).navKey);
                    },
                    '/course_grades': (BuildContext context) =>
                        CourseGradesScreen(),
                    '/feed': (BuildContext context) => FeedScreen(),
                    '/home': (BuildContext context) => HomeScreen(),
                    '/grades_detail': (BuildContext context) =>
                        GradeItemDetailScreen(),
                    '/academic_info': (BuildContext context) =>
                        AcademicInfoScreen(),
                  },
                ),
              ),
              if (Provider.of<CurrentSession>(context).isOffline)
                OfflineStatusBar(),
            ],
          );
        },
      ),
    );
  }

  ThemeData _buildCurrentTheme(ThemeController theme) {
    switch (theme.currentTheme) {
      case 'dark':
        return ThemeData(
          primaryColor: const Color(0xff195080),
          accentColor: const Color(0xff216bac),
          cardColor: const Color(0xff226baa),
          brightness: Brightness.dark,
          primaryColorLight: Colors.white,
        );
      case 'light':
      default:
        return ThemeData(
          primaryColor: const Color(0xff2a84d2),
          accentColor: const Color(0xff216bac),
          cardColor: const Color(0xffffffff),
          primaryColorLight: Colors.black,
          brightness: Brightness.light,
        );
    }
  }
}

class OfflineStatusBar extends StatefulWidget {
  OfflineStatusBar({Key key}) : super(key: key);

  @override
  _OfflineStatusBarState createState() => _OfflineStatusBarState();
}

class _OfflineStatusBarState extends State<OfflineStatusBar> {
  bool _loggingIn = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        color: Colors.orange,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.0),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'No Network Connection',
                ),
                const SizedBox(width: 40),
                Align(
                  alignment: Alignment.centerRight,
                  child: FlatButton(
                    color: Colors.orangeAccent,
                    onPressed: () async {
                      var secure = const WrappedSecureStorage();
                      var email = await secure.read(key: 'sis_email');
                      var password = await secure.read(key: 'sis_password');
                      var session = await secure.read(key: 'sis_session');

                      if (mounted) {
                        setState(() {
                          _loggingIn = true;
                        });
                      }

                      try {
                        var loader = await attemptLogin(
                          email,
                          password,
                          session,
                        );
                        Provider.of<CurrentSession>(context, listen: false)
                            .setSisLoader(loader);
                        Provider.of<CurrentSession>(context, listen: false)
                            .setOfflineStatus(false);
                      } catch (_) {}
                      if (mounted) {
                        setState(() {
                          _loggingIn = false;
                        });
                      }
                    },
                    child: Row(
                      children: <Widget>[
                        const Text(
                          'Refresh',
                          style: TextStyle(color: Colors.white),
                        ),
                        if (_loggingIn)
                          const Padding(
                            padding: EdgeInsets.only(left: 10.0),
                            child: SpinKitRing(
                              color: Colors.white,
                              lineWidth: 3,
                              size: 20.0,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

mixin PortraitModeMixin on StatelessWidget {
  @override
  Widget build(BuildContext context) {
    _portraitModeOnly();
    return null;
  }
}

/// Forces portrait-only mode in mixin
mixin PortraitStatefulModeMixin<T extends StatefulWidget> on State<T> {
  @override
  Widget build(BuildContext context) {
    _portraitModeOnly();
    return null;
  }

  @override
  void dispose() {
    _enableRotation();
    super.dispose();
  }
}

/// blocks rotation; sets orientation to: portrait
void _portraitModeOnly() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

void _enableRotation() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}
