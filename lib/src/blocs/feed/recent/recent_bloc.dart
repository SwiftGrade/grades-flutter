// TODO: Implement "unread" grades
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:sis_loader/sis_loader.dart';

import '../../../repos/sis_repository.dart';
import '../feed.dart';
import '../feed_event.dart';

part 'recent_state.dart';

class RecentBloc extends Bloc<FeedEvent, RecentState> {
  final SISRepository _sisRepository;

  StreamSubscription<FeedEvent> _courseFetchingSubscription;

  RecentBloc({@required SISRepository sisRepository})
      : assert(sisRepository != null),
        _sisRepository = sisRepository;

  @override
  RecentState get initialState => RecentLoading.empty();

  @override
  Stream<RecentState> mapEventToState(
    FeedEvent event,
  ) async* {
    if (event is FetchData) {
      yield RecentLoading.empty();
      yield* _fetchCourseData();
    } else if (event is RefreshData) {
      if (state is RecentLoaded) {
        // Preserve the currently loaded courses, we will update the underlying map
        // with new data
        yield RecentLoading((state as RecentLoaded).courses);
        yield* _fetchCourseData();
      }
    } else if (event is GradesLoaded) {
      yield* _mapGradeLoadedToState(event);
    } else if (event is DoneLoading) {
      yield* _mapDoneLoadingToState();
    }
  }

  Stream<RecentState> _fetchCourseData() async* {
    var courses = await _sisRepository.getCourses();

    await _courseFetchingSubscription?.cancel();
    _courseFetchingSubscription =
        fetchCourseGrades(_sisRepository, courses, isGradeRecent)
            .listen((event) => add(event));
  }

  Stream<RecentState> _mapGradeLoadedToState(GradesLoaded event) async* {
    if (state is RecentLoading) {
      var grades = Map.of((state as RecentLoading).partialCourses);
      grades[event.course] = event.grades;
      yield RecentLoading(grades);
    } else {
      // We probably shouldn't be able to get a GradeLoaded if we are already
      // fully loaded
      throw Exception('Unexpected state');
    }
  }

  Stream<RecentState> _mapDoneLoadingToState() async* {
    if (state is RecentLoading) {
      yield (state as RecentLoading).complete();
    } else {
      // We probably shouldn't be able to get a DoneLoaded if we are already
      // fully loaded
      throw Exception('Unexpected state');
    }
  }

  @override
  Future<void> close() {
    _courseFetchingSubscription?.cancel();
    return super.close();
  }
}

bool isGradeRecent(Grade grade) {
  if (grade.dateLastModified != null && grade.dateLastModified is DateTime) {
    var gradeDate = grade.dateLastModified;
    return gradeDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  } else {
    return false;
  }
}
