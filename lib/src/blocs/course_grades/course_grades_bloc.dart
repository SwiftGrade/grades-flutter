import 'package:flutter/cupertino.dart';
import 'package:grade_core/grade_core.dart';
import 'package:sis_loader/sis_loader.dart';

import '../network_action_bloc/network_action_bloc.dart';

class CourseGradesBloc extends NetworkActionBloc<List<Grade>> {
  final SISRepository _sisRepository;
  final Course _course;

  CourseGradesBloc({
    @required SISRepository sisRepository,
    @required Course course,
  })  : assert(sisRepository != null),
        assert(course != null),
        _sisRepository = sisRepository,
        _course = course;

  @override
  Future<List<Grade>> fetch() async {
    return await _sisRepository.getCourseGrades(_course);
  }
}
