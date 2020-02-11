import 'dart:io';

import 'package:flutter/material.dart';
import 'package:grades/models/current_session.dart';
import 'package:grades/utilities/sentry.dart';
import 'package:grades/utilities/stacked_future_builder.dart';
import 'package:grades/widgets/class_list_item_widget.dart';
import 'package:grades/widgets/loader_widget.dart';
import 'package:grades/widgets/refreshable_error_message.dart';
import 'package:pedantic/pedantic.dart';
import 'package:provider/provider.dart';
import 'package:sis_loader/sis_loader.dart';

class CourseListScreen extends StatefulWidget {
  CourseListScreen({Key key}) : super(key: key);

  @override
  _CourseListScreenState createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  Future<List<Course>> _courses;

  Future<List<Course>> _init() {
    if (_courses == null) {
      _courses = _setup();
    }
    return _courses;
  }

  Future<List<Course>> _setup() async {
    var courses = await Provider.of<CurrentSession>(context, listen: false)
        .sisLoader
        .getCourses();

    // TODO: Is this useful?
    // Preload course grades
    unawaited(
      Future.wait(courses.map((course) async {
        unawaited(course.getGrades());
      })),
    );
    return courses;
  }

  Future<List<Course>> _callback() async {
    return Provider.of<CurrentSession>(context, listen: false)
        .sisLoader
        .getCourses(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: StackedFutureBuilder<List<Course>>(
        future: _init(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return RefreshIndicator(
              onRefresh: _callback,
              child: ListView.builder(
                itemCount: snapshot.data.length,
                itemBuilder: (BuildContext context, int index) {
                  var course = snapshot.data[index];
                  return ClassListItemWidget(
                    onTap: () {
                      Navigator.pushNamed(context, '/course_grades',
                          arguments: course);
                    },
                    course: course.courseName,
                    letterGrade: course.gradeLetter,
                    teacher: course.teacherName,
                    percent: course.gradePercent,
                  );
                },
              ),
            );
          } else if (snapshot.hasError) {
            if (snapshot.error is SocketException ||
                snapshot.error is HttpException ||
                snapshot.error is HandshakeException ||
                snapshot.error is OSError) {
              return RefreshableErrorMessage(
                onRefresh: _callback,
                text: "Issue connecting to SIS",
              );
            }

            reportException(
              exception: snapshot.error,
              stackTrace: snapshot.stackTrace,
            );

            // TODO: Find the root cause of this
            if (snapshot.error is NoSuchMethodError ||
                snapshot.error is UnknownStructureException) {
              return RefreshableErrorMessage(
                onRefresh: _callback,
                text: "There was an unknown error.\nYou may need to log out.",
              );
            }

            return RefreshableErrorMessage(
              onRefresh: _callback,
              text:
                  "An error occured loading courses:\n\n${snapshot.error}\n\nPull to refresh.\nIf the error persists, restart the app.",
            );
          }
          return Center(
            child: LoaderWidget(),
          );
        },
      ),
    );
  }
}
