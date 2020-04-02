import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grades/providers/current_session.dart';
import 'package:grades/providers/data_persistence.dart';
import 'package:grades/providers/theme_controller.dart';
import 'package:grades/screens/academic_information_screen.dart';
import 'package:grades/screens/course_grades_screen.dart';
import 'package:grades/screens/course_list_screen.dart';
import 'package:grades/screens/feed_screen.dart';
import 'package:grades/screens/grade_item_detail_screen.dart';
import 'package:grades/screens/home_screen.dart';
import 'package:grades/screens/login_screen.dart';
import 'package:grades/screens/settings_screen.dart';
import 'package:grades/screens/splash_screen.dart';
import 'package:grades/screens/terms_display_screen.dart';
import 'package:grades/screens/terms_query_screen.dart';
import 'package:grades/utilities/helpers/package_info.dart';
import 'package:grades/utilities/sentry.dart';
import 'package:grades/widgets/offline_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sis_loader/sis_loader.dart';

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
    var client = CookieClient();
    GLOBAL_DATA_PERSISTENCE = DataPersistence(prefs, client);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CurrentSession(
            dataPersistence: GLOBAL_DATA_PERSISTENCE,
            client: client,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ThemeController(prefs)),
        ChangeNotifierProvider(create: (_) => GLOBAL_DATA_PERSISTENCE),
      ],
      child: Consumer<ThemeController>(
        builder: (BuildContext context, ThemeController theme, Widget child) {
          return MaterialApp(
            navigatorKey: _navKey,
            title: 'SwiftGrade',
            debugShowCheckedModeBanner: false,
            builder: (BuildContext context, Widget child) {
              return Column(
                children: <Widget>[
                  Expanded(child: child),
                  if (Provider.of<CurrentSession>(context).isOffline)
                    OfflineStatusBar(),
                ],
              );
            },
            home: SplashScreen(),
            theme: _buildCurrentTheme(theme),
            routes: <String, WidgetBuilder>{
              '/login': (BuildContext context) => LoginScreen(),
              '/terms': (BuildContext context) => TermsQueryScreen(),
              '/terms_settings': (BuildContext context) => TermsDisplayScreen(),
              '/settings': (BuildContext context) => SettingsScreen(),
              '/courses': (BuildContext context) {
                // Use a key here to prevent overlap in sessions
                return CourseListScreen(
                    key: Provider.of<CurrentSession>(context).navKey);
              },
              '/course_grades': (BuildContext context) => CourseGradesScreen(),
              '/feed': (BuildContext context) => FeedScreen(),
              '/home': (BuildContext context) => HomeScreen(),
              '/grades_detail': (BuildContext context) =>
                  GradeItemDetailScreen(),
              '/academic_info': (BuildContext context) => AcademicInfoScreen(),
            },
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
