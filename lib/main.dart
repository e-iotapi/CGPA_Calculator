import 'dart:io';
import 'package:cgpa_calculator/offshoot.dart';
import 'package:path/path.dart' as p;
import 'package:cgpa_calculator/analytics.dart';
// import 'dart:html' as html;
// import 'dart:js' as js;
import 'package:cgpa_calculator/course.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cgpa_calculator/settings.dart';
import 'package:cgpa_calculator/script.dart';
import 'package:cgpa_calculator/mastercourselist.dart';
import 'package:cgpa_calculator/constants.dart';
import 'dart:math';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cgpa_calculator/home_page.dart';

//html and js imports and uses to be removed for android build

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    String hivePath;
    if (Platform.isWindows) {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      hivePath = p.join(exeDir, 'Hive');
      await Hive.initFlutter(hivePath);
    } else {
      await Hive.initFlutter();
    }
  } else {
    await Hive.initFlutter();
  }
  Hive.registerAdapter(CourseAdapter());
  //await Hive.openBox<Course>('coursesBox');
  await basicStartup();
  if (!kIsWeb) {
    mcourselist = await loadMcourselistFromFile();
  }
  //await initializeCourses();
  //await Future.delayed(Duration(milliseconds: 40));
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final maxwindowsscreen = await screenRetriever.getPrimaryDisplay();
      final maxwindowsheight = maxwindowsscreen.size.height.toDouble();
      await windowManager.ensureInitialized();
      //await windowManager.setAspectRatio(9.5 / 18);
      //await windowManager.setMaximumSize(Size(maxwindowsheight * 9.5 / 18, maxwindowsheight));
      //await windowManager.setMinimumSize(Size(720 * 9.5 / 18, 720));
      //await windowManager.setAsFrameless();
      WindowOptions windowOptions = WindowOptions(
        size: Size(maxwindowsheight * 9.5 / 18, maxwindowsheight),
        //center: true,
        //backgroundColor: themes.firstWhere((t) => t.theme == selected_theme).backcolor,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
      title: 'CGPA Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: thm.highcolor),
      ),
      home: const MyHomePage(title: 'CGPA CALCULATOR'),
    );
  }
}

