import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:grades/models/grade_persistence.dart';
import 'package:grades/utilities/sentry.dart';
import 'package:grades/utilities/stacked_future_builder.dart';
import 'package:grades/widgets/course_grades_full_display.dart';
import 'package:grades/widgets/course_grades_minimal_display.dart';
import 'package:grades/widgets/loader_widget.dart';
import 'package:grades/widgets/refreshable_error_message.dart';
import 'package:grades/widgets/refreshable_icon_message.dart';
import 'package:provider/provider.dart';
import 'package:sis_loader/sis_loader.dart';

enum DisplayStyle { Full, Minimal }

class CourseGradesScreen extends StatefulWidget {
  @override
  _CourseGradesScreenState createState() => _CourseGradesScreenState();
}

class _CourseGradesScreenState extends State<CourseGradesScreen> {
  Future<FetchedCourseData> _data;
  bool _loaded = false;
  bool _hasCategories = false;
  DisplayStyle _displayStyle = DisplayStyle.Minimal;
  GroupingMode _groupingMode = GroupingMode.Category;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _data = _fetchData();
    }
  }

  Future<FetchedCourseData> _fetchData([bool force = false]) async {
    final Course course = ModalRoute.of(context).settings.arguments as Course;

    var grades = await course.getGrades(force);
    setState(() {
      _loaded = true;
      if (grades.every((element) => element.containsKey("Category"))) {
        _hasCategories = true;
      }
      Provider.of<GradePersistence>(context, listen: false)
          .insert(course.courseName, grades);
    });

    return FetchedCourseData(grades, await course.getCategoryWeights(force));
  }

  Future<FetchedCourseData> _refresh() async {
    _data = _fetchData(true);
    return _data;
  }

  @override
  Widget build(BuildContext context) {
    final Course course = ModalRoute.of(context).settings.arguments as Course;

    return Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          elevation: 0.0,
          centerTitle: true,
          title: Text("${course.courseName}"),
          leading: IconButton(
            tooltip: "Back",
            icon: Icon(
              Icons.arrow_back_ios,
            ),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          actions: [
            if (_displayStyle == DisplayStyle.Minimal && _hasCategories)
              IconButton(
                icon: Icon(_groupingMode == GroupingMode.Category
                    ? Icons.today
                    : Icons.format_list_bulleted),
                onPressed: () {
                  setState(() {
                    _groupingMode = _groupingMode == GroupingMode.Category
                        ? GroupingMode.Date
                        : GroupingMode.Category;
                  });
                },
              ),
            // IconButton(
            //   // TODO: Pick a better icon
            //   icon: Icon(_displayStyle == DisplayStyle.Minimal
            //       ? Icons.unfold_more
            //       : Icons.unfold_less),
            //   onPressed: () {
            //     setState(() {
            //       _displayStyle = _displayStyle == DisplayStyle.Minimal
            //           ? DisplayStyle.Full
            //           : DisplayStyle.Minimal;
            //     });
            //   },
            // )
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: StackedFutureBuilder<FetchedCourseData>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data.grades.isEmpty) {
                    return RefreshableIconMessage(
                      onRefresh: _refresh,
                      icon: Icon(
                        FontAwesomeIcons.inbox,
                        size: 55,
                        color: Colors.white,
                      ),
                      child: const Text(
                        "There are no grades listed in this class",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17.0,
                        ),
                      ),
                    );
                  }
                  if (_displayStyle == DisplayStyle.Full) {
                    return CourseGradesFullDisplay(
                        cleanupData(snapshot.data.grades));
                  } else {
                    return CourseGradesMinimalDisplay(
                      snapshot.data.grades,
                      snapshot.data.categoryWeights,
                      _hasCategories ? _groupingMode : GroupingMode.Date,
                    );
                  }
                } else if (snapshot.hasError) {
                  if (snapshot.error is SocketException ||
                      snapshot.error is HttpException ||
                      snapshot.error is HandshakeException ||
                      snapshot.error is OSError) {
                    return RefreshableErrorMessage(
                      onRefresh: _refresh,
                      text: "Issue connecting to SIS",
                    );
                  }
                  reportException(
                    exception: snapshot.error,
                    stackTrace: snapshot.stackTrace,
                  );

                  return RefreshableErrorMessage(
                    onRefresh: _refresh,
                    text:
                        "An error occured fetching grades:\n\n${snapshot.error}\n\nPull to refresh.\nIf the error persists, restart the app.",
                  );
                }

                return Center(child: LoaderWidget());
              }),
        ));
  }
}

List<Map<String, dynamic>> cleanupData(List<Map<String, dynamic>> data) {
  Map<String, bool> values = {};

  for (var record in data) {
    for (var e in record.entries) {
      if (e.value != null) {
        values[e.key] = true;
      }
    }
  }

  List<Map<String, dynamic>> out = [];
  for (var record in data) {
    Map<String, dynamic> outRecord = {};
    for (var e in record.entries) {
      if (values[e.key] != null) {
        outRecord[e.key] = e.value;
      }
    }
    out.add(outRecord);
  }

  return out;
}

class FetchedCourseData {
  final List<Map<String, dynamic>> grades;
  final Map<String, String> categoryWeights;

  FetchedCourseData(this.grades, this.categoryWeights);
}
