import 'package:flutter/material.dart';
import 'package:grades/models/current_session.dart';
import 'package:grades/screens/course_list_screen.dart';
import 'package:grades/screens/login_screen.dart';
import 'package:provider/provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // root of application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => CurrentSession())],
        child: MaterialApp(
          title: 'Flutter Login UI',
          debugShowCheckedModeBanner: false,
          home: LoginScreen(),
          theme: ThemeData(
              brightness: Brightness.dark, primaryColor: Colors.blueGrey),
          routes: <String, WidgetBuilder>{
            '/courses': (BuildContext context) => CourseListScreen()
          },
        ));
  }
}
