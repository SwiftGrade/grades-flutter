import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grade_core/grade_core.dart';
import 'package:grades/screens/home_screen/course_list_page.dart';
import 'package:grades/screens/home_screen/recent_page.dart';
import 'package:grades/screens/home_screen/upcoming_page.dart';
import 'package:grades/widgets/page_indicator.dart';
import 'package:tuple/tuple.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController controller = PageController(initialPage: 1);
  List<Tuple2<String, Widget>> pages = [
    Tuple2('RECENT', RecentPage()),
    Tuple2('COURSES', CourseListPage()),
    Tuple2('UPCOMING', UpcomingPage()),
  ];
  String title = 'COURSES';

  List<BlocProvider<dynamic>> providers;

  List<BlocProvider> _buildProviders(SISRepository sisRepository) {
    return [
      BlocProvider<RecentBloc>(
        create: (_) =>
            RecentBloc(sisRepository: sisRepository)..add(FetchData()),
      ),
      BlocProvider<CourseListBloc>(
        create: (_) => CourseListBloc(sisRepository: sisRepository)
          ..add(FetchNetworkData()),
      ),
      BlocProvider<UpcomingBloc>(
        create: (_) =>
            UpcomingBloc(sisRepository: sisRepository)..add(FetchData()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        title: Text(title),
        leading: IconButton(
          tooltip: 'Profile',
          icon: Icon(
            Icons.person,
          ),
          onPressed: () => Navigator.pushNamed(context, '/academic_info'),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          MultiBlocProvider(
            providers: providers ??=
                _buildProviders(RepositoryProvider.of<SISRepository>(context)),
            child: PageView.builder(
              controller: controller,
              itemCount: pages.length,
              onPageChanged: (i) {
                setState(() {
                  title = pages[i].item1;
                });
              },
              itemBuilder: (context, position) => pages[position].item2,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20.0),
            alignment: Alignment.bottomCenter,
            child: PageIndicator(
              controller: controller,
              itemCount: pages.length,
              onPageSelected: (int page) {
                controller.animateToPage(
                  page,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
