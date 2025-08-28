import 'dart:io';
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
import 'settings.dart';
import 'mastercourselist.dart';
import 'constants.dart';
import 'dart:math';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

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
  }
  else {
    await Hive.initFlutter();
  }
  Hive.registerAdapter(CourseAdapter());
  //await Hive.openBox<Course>('coursesBox');
  await basicStartup();
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

Future<void> basicStartup() async{
  var settingsBox = await Hive.openBox('settingsBox');
  final coursesBox = await Hive.openBox<Course>('coursesBox');
  selecteddiscipline = settingsBox.get('selecteddiscipline', defaultValue: selecteddiscipline,);
  batch = settingsBox.get('batch', defaultValue: 24,);
  selectedcampus = settingsBox.get('selectedcampus', defaultValue: selectedcampus,);
  selected_theme = settingsBox.get('selected_theme', defaultValue: selected_theme,);
  degree_selected = settingsBox.get('degree_selected', defaultValue: false);
  currentsort = settingsBox.get('currentsort', defaultValue: currentsort);
  currentsem = settingsBox.get('currentsem', defaultValue: currentsem);
  profile1n = settingsBox.get('profile1n', defaultValue: profile1n);
  profile2n = settingsBox.get('profile2n', defaultValue: profile2n);
}

Future<void> initializeCourses() async {
  var settingsBox = await Hive.openBox('settingsBox');
  final coursesBox = await Hive.openBox<Course>('coursesBox');
  selecteddiscipline = settingsBox.get('selecteddiscipline', defaultValue: selecteddiscipline,);
  batch = settingsBox.get('batch', defaultValue: 24,);
  selectedcampus = settingsBox.get('selectedcampus', defaultValue: selectedcampus,);
  selected_theme = settingsBox.get('selected_theme', defaultValue: selected_theme,);
  degree_selected = settingsBox.get('degree_selected', defaultValue: false);
  currentsort = settingsBox.get('currentsort', defaultValue: currentsort);
  currentsem = settingsBox.get('currentsem', defaultValue: currentsem);
  profile1n = settingsBox.get('profile1n', defaultValue: profile1n);
  profile2n = settingsBox.get('profile2n', defaultValue: profile2n);
  print(erase);
  if (erase == 1) {
    await coursesBox.clear();
      String tempsem = "";
      List <String> tempaddedcourses =[];
      for (var course in ((batch < 25)?(selectedcampus=="Hyd")?hydCourseList:(selectedcampus=="Goa")?goaCourseList:pilaniCourseList:(selectedcampus=="Hyd")?hydCourseListNew:(selectedcampus=="Goa")?goaCourseListNew:pilaniCourseListNew) ){
        if (course.discipline ==
            ((selecteddiscipline.substring(0, 2) != "--")
                ? selecteddiscipline.substring(0, 2)
                : selecteddiscipline.substring(2, 4))) {
          await coursesBox.put(course.id, course);
          tempaddedcourses.add(course.title);
        }
        if (course.discipline ==
            ((selecteddiscipline.substring(0, 2) != "--")
                ? selecteddiscipline.substring(2, 4)
                : "cccc")) {
          if (course.elective == "CDC2" && !tempaddedcourses.contains(course.title)) {
            if(selecteddiscipline == "B5AA" || selecteddiscipline == "B5A3"|| selecteddiscipline == "B5A8" || selecteddiscipline == "B4AD"){
              if((course.title=="Algebra I" || course.title=="Discrete Mathematics" ||course.title=="Elementary Real Analysis" ||course.title=="Numerical Analysis" || course.title == "Electromagnetic Theory")){}
              else{
              tempsem = course.sem;
              tempsem =
                  (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                      tempsem.substring(1, 5);
              //print(tempsem);
              Course Course1 = Course(
                title: course.title,
                sem: tempsem,
                id: course.id,
                grade1: course.grade1,
                grade2: course.grade2,
                discipline: course.discipline,
                credits: course.credits,
                elective: course.elective,
              );
              try {
                await coursesBox.put(Course1.id, Course1);
                //print('Stored modified course with id: ${course.id}');
              } catch (e) {
                //print('Error storing course: $e');
              }
            }}
              else{
                tempsem = course.sem;
                tempsem =
                    (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                        tempsem.substring(1, 5);
                //print(tempsem);
                Course Course1 = Course(
                  title: course.title,
                  sem: tempsem,
                  id: course.id,
                  grade1: course.grade1,
                  grade2: course.grade2,
                  discipline: course.discipline,
                  credits: course.credits,
                  elective: course.elective,
                );
                try {
                  await coursesBox.put(Course1.id, Course1);
                  //print('Stored modified course with id: ${course.id}');
                } catch (e) {
                  //print('Error storing course: $e');
                }
            }
          }
        }
      }
      //print("All keys in coursesBox: ${coursesBox.keys}");
      setsort();
  }
  else if (erase == 0) {
    if (degree_selected == true) {
      if (!coursesBox.values.any(
            (course) =>
        course.discipline ==
            ((selecteddiscipline.startsWith("B"))
                ? selecteddiscipline.substring(0, 2)
                : selecteddiscipline.substring(2, 4)) ||
            course.discipline ==
                ((selecteddiscipline.startsWith("B"))
                    ? selecteddiscipline.substring(2, 4)
                    : "ccccc"),
      )) {
        String tempsem = "";
        for (var course in ((batch < 25)
            ? (selectedcampus == "Hyd")
            ? hydCourseList
            : (selectedcampus == "Goa") ? goaCourseList : pilaniCourseList
            : (selectedcampus == "Hyd") ? hydCourseListNew : (selectedcampus ==
            "Goa") ? goaCourseListNew : pilaniCourseListNew)) {
          if (course.discipline ==
              ((selecteddiscipline.substring(0, 2) != "--")
                  ? selecteddiscipline.substring(0, 2)
                  : selecteddiscipline.substring(2, 4))) {
            await coursesBox.put(course.id, course);
          }
          if (course.discipline ==
              ((selecteddiscipline.substring(0, 2) != "--")
                  ? selecteddiscipline.substring(2, 4)
                  : "cccc")) {
            if (selecteddiscipline == "B5AA" || selecteddiscipline == "B5A3" ||
                selecteddiscipline == "B5A8" || selecteddiscipline == "B4AD") {
              if ((course.title == "Algebra I" ||
                  course.title == "Discrete Mathematics" ||
                  course.title == "Elementary Real Analysis" ||
                  course.title == "Numerical Analysis" ||
                  course.title == "Electromagnetic Theory")) {}
              else{
                if (course.elective == "CDC2") {
                  tempsem = course.sem;
                  tempsem =
                      (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                          tempsem.substring(1, 5);
                  //print(tempsem);
                  Course Course1 = Course(
                    title: course.title,
                    sem: tempsem,
                    id: course.id,
                    grade1: course.grade1,
                    grade2: course.grade2,
                    discipline: course.discipline,
                    credits: course.credits,
                    elective: course.elective,
                  );

                  try {
                    await coursesBox.put(Course1.id, Course1);
                    //print('Stored modified course with id: ${course.id}');
                  } catch (e) {
                    //print('Error storing course: $e');
                  }
                }
              }
            }
              else {
                if (course.elective == "CDC2") {
                  tempsem = course.sem;
                  tempsem =
                      (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                          tempsem.substring(1, 5);
                  //print(tempsem);
                  Course Course1 = Course(
                    title: course.title,
                    sem: tempsem,
                    id: course.id,
                    grade1: course.grade1,
                    grade2: course.grade2,
                    discipline: course.discipline,
                    credits: course.credits,
                    elective: course.elective,
                  );

                  try {
                    await coursesBox.put(Course1.id, Course1);
                    //print('Stored modified course with id: ${course.id}');
                  } catch (e) {
                    //print('Error storing course: $e');
                  }
                }
              }
          }
          //print("All keys in coursesBox: ${coursesBox.keys}");
          setsort();
        }
      }
    }
  }
  else if (erase == 2) {
    print("running");
    final keysToDelete = [];
    final tempcourses = [];
    for (final entry in coursesBox.toMap().entries) {
      final key = entry.key;
      final item = entry.value;
      if(item.discipline.startsWith("B")){
        tempcourses.add(item.title);
      }
      if (item.discipline.startsWith("A") &&
          item.elective == "CDC2" &&
          !item.sem.startsWith("1")) {
        if (selecteddiscipline.startsWith("B") && !item.sem.startsWith("1")) {
          keysToDelete.add(key);
        } else if (!selecteddiscipline.startsWith("B")) {
          keysToDelete.add(key);
        }
      }
    }
    if (keysToDelete.isNotEmpty) {
      await coursesBox.deleteAll(keysToDelete);
    }
    print("1");
    String tempsem = "";
    for (var course in ((batch < 25)?(selectedcampus=="Hyd")?hydCourseList:(selectedcampus=="Goa")?goaCourseList:pilaniCourseList:(selectedcampus=="Hyd")?hydCourseListNew:(selectedcampus=="Goa")?goaCourseListNew:pilaniCourseListNew) ){
      //print("0");
      if (course.discipline == selecteddiscipline.substring(2, 4)) {
        //print("A");
        if(!tempcourses.contains(course.title)){
            //print("B");
            if(selecteddiscipline == "B5AA" || selecteddiscipline == "B5A3"|| selecteddiscipline == "B5A8" || selecteddiscipline== "B4AD"){
              //print("C");
              if(!(course.title=="Algebra I" || course.title=="Discrete Mathematics" ||course.title=="Elementary Real Analysis" ||course.title=="Numerical Analysis" || course.title == "Electromagnetic Theory")){

               // print("D");
                if (course.elective == "CDC2" && selecteddiscipline.startsWith("B")) {
                tempsem = course.sem;
                tempsem =
                    (int.parse(tempsem.substring(0, 1)) + 1).toString() +
                        tempsem.substring(1, 5);
                //print(tempsem);
                Course Course1 = Course(
                  title: course.title,
                  sem: tempsem,
                  id: course.id,
                  grade1: course.grade1,
                  grade2: course.grade2,
                  discipline: course.discipline,
                  credits: course.credits,
                  elective: course.elective,
                );
                try {
                  await coursesBox.put(Course1.id, Course1);
                  //print('Stored modified course with id: ${course.id}');
                } catch (e) {
                  //print('Error storing course: $e');
                }
              }
              }
            }
              else{
        if (course.elective == "CDC2" && selecteddiscipline.startsWith("B")) {
          tempsem = course.sem;
          tempsem =
              (int.parse(tempsem.substring(0, 1)) + 1).toString() +
              tempsem.substring(1, 5);
          //print(tempsem);
          Course Course1 = Course(
            title: course.title,
            sem: tempsem,
            id: course.id,
            grade1: course.grade1,
            grade2: course.grade2,
            discipline: course.discipline,
            credits: course.credits,
            elective: course.elective,
          );
          try {
            await coursesBox.put(Course1.id, Course1);
          } catch (e) {
            //print('Error storing course: $e');
          }
        }}}
        } else if (selecteddiscipline.startsWith("--")) {
          //print("abc");
          await coursesBox.put(course.id, course);
        }
        //await coursesBox.put(course.id, course);
      }
    }
    //print("All keys in coursesBox: ${coursesBox.keys}");
}

Future<void> setdis() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('batch', batch);
  await settingsBox.put('selecteddiscipline', selecteddiscipline);
  await settingsBox.put('selectedcampus', selectedcampus);
  await settingsBox.put('degree_selected', true);
}

Future<void> setsort() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('currentsort', currentsort);
}

Future<void> settheme() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('selected_theme', selected_theme);
}

Future<void> setsem() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('currentsem', currentsem);
}

Future<void> setprof() async {
  var settingsBox = await Hive.openBox('settingsBox');
  await settingsBox.put('profile1n', profile1n);
  await settingsBox.put('profile2n', profile2n);
}

Future<void> removeCourseById(String targetId) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.delete(targetId);
    await box.flush();
    await box.compact();
  } catch (e) {}
}

Future<void> addCourse(Course course) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.add(course);
    await box.flush();
  } catch (e) {}
}

Future<void> addOrUpdateCourse(Course course) async {
  try {
    var box = Hive.box<Course>('coursesBox');
    await box.put(course.id, course);
    await box.flush();
  } catch (e) {}
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
        colorScheme: ColorScheme.fromSeed(
          seedColor:
              thm.highcolor,
        ),
      ),
      home: const MyHomePage(title: 'CGPA CALCULATOR'),
    );
  }
}

var thm = themes.firstWhere((x) => x.theme == selected_theme);
double sgpa = 0.00;
double cgpa = 0.00;
int tapid = 0;
int batch = 24;
String selecteddiscipline = "----"; //store
String selectedcampus = "Hyd";
int selectedprofile = 1;
int selectedgrade = 10;
String selectedelective = "None";
String currentsem = "1 - 1"; // store
int scred1 = 0;
int scred2 = 0;
int ccred1 = 0;
int ccred2 = 0;
String profile1n = "Actual";
String profile2n = "Expected";

String addcourse = "AN";
String currentsort = "Sort by Credits(Asc)"; //store
String selected_theme = "White";
bool degree_selected = false;
int erase = 0;
bool isUpdating = false;
String addcourseid = dropdownid[0];
List<String> anCourseIds =
    mcourselist
        .where((course) => course.id.startsWith('AN '))
        .map((course) => course.id.replaceFirst('AN ', ''))
        .toList();
List<String> dropdownid = anCourseIds;
final List<String> depts = ["AN","BIO","BIOT","BITS","CE","CHE","CHEM","CS","ECE","ECON","ECOM","EEE","FIN","GS","HSS","INSTR","IS","MAC","MATH","ME","MF","MGTS","MSE","MST","PHA","PHY","SNS",];
final List<String> grades = ["A","A-","B","B-","C","C-","D","E","NC","CLR","GD"];
final List<String> sems = ["1 - 1","1 - 2","2 - 1","2 - 2","PS 1","3 - 1","3 - 2","ST 1","4 - 1","4 - 2",];
final List<String> degreelist = ["B1","B2","B3","B4","B5","B7","A1","A2","A3","A4","A5","A7","A8","A9","AA","AB","AC","AD","AJ"];
final List<String> campuslist = ["Pilani", "Goa", "Hyd"];

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

String gradecalc(int s) {
  return (s == 10)
      ? "A"
      : (s == 9)
      ? "A-"
      : (s == 8)
      ? "B"
      : (s == 7)
      ? "B-"
      : (s == 6)
      ? "C"
      : (s == 5)
      ? "C-"
      : (s == 4)
      ? "D"
      : (s == 2)
      ? "E"
      : (s == -1)
      ? "NC"
      : (s == -2)
      ? "CLR"
      : (s == -3)
      ? "GD"
      : (s == -5)
      ? "–"
      : "?";
}

String electiveFinder(String s){
if(s== "CDC2"){
  return selecteddiscipline.substring(2,4) + " " + "CDC";
}else if(s== "CDC1"){
  return selecteddiscipline.substring(0,2) + " " + "CDC";
}else if(s== "CDCN"){
  return "None";
}else if(s== "Open Elective"){
  return "Open Elective";
}else if(s== "Disciplinary Elective2"){
  return selecteddiscipline.substring(2,4) + " " +"Disciplinary Elective";
}else if(s== "Disciplinary Elective1"){
  return selecteddiscipline.substring(0,2) + " " +"Disciplinary Elective";
}else if(s== "Humanity Elective"){
  return "Humanity Elective";
}
else {
  return s;
}
}

int reversegradecalc(String s) {
  return (s == "A")
      ? 10
      : (s == "A-")
      ? 9
      : (s == "B")
      ? 8
      : (s == "B-")
      ? 7
      : (s == "C")
      ? 6
      : (s == "C-")
      ? 5
      : (s == "D")
      ? 4
      : (s == "E")
      ? 2
      : (s == "NC")
      ? -1
      : (s == "CLR")
      ? -2
      : (s == "GD")
      ? -3
      : -100;
}

void setnavcolor() {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor:
          thm.backcolor,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if(!kIsWeb){
        if(Platform.isAndroid){
          final updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => AlertDialog(
                  backgroundColor: thm.backcolor,
                  title: Text('Update Available', style: TextStyle(color: thm.textcolor)),
                  content: Text('An Update is Available. Update now?', style: TextStyle(color: thm.textcolor)),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await launchUrl(
                                      Uri.parse(
                                          'https://play.google.com/store/apps/details?id=com.srijen.cgpa_calculator'),
                                    );
                      },
                      child: Text('Update',style: TextStyle(color: thm.highcolor)),
                    ),
                  ],
                ),
              );
            }
          }
        }
      }
    });
  }

  List<Course> get items =>
      Hive.box<Course>('coursesBox').values
          .where(
            (course) =>
                course.sem == currentsem &&
                (course.discipline ==
                        ((selecteddiscipline.substring(0, 2) != "--")
                            ? selecteddiscipline.substring(0, 2)
                            : selecteddiscipline.substring(2, 4)) ||
                    course.discipline ==
                        ((selecteddiscipline.substring(0, 2) != "--")
                            ? selecteddiscipline.substring(2, 4)
                            : "ccccc")),
          )
          .toList();

  bool _isCardOpen = false;
  bool _isGradeChanged = false;
  bool _isDisciplineChanged = false;
  bool _isCourseCardOpen = false;
  bool _isrightswipe = true;
  bool _isSearched = false;
  TextEditingController _batchController1 = TextEditingController(text: batch.toString());
  String name1 =
      mcourselist
          .firstWhere(
            (course) => course.id == ("$addcourse $addcourseid"),
            orElse: () => Mastercourselist(id: '', title: '', credits: 0),
          )
          .title;
  int credits1 =
      mcourselist
          .firstWhere(
            (course) => course.id == ("$addcourse $addcourseid"),
            orElse: () => Mastercourselist(id: '', title: '', credits: 0),
          )
          .credits;

  double sgcalc(String s) {
    var allCourses = Hive.box<Course>('coursesBox').values.where(
      (course) =>
          course.sem == s &&
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)),
    );
   int dontCount =0;
    int s1 = 0;
    if (selectedprofile == 1) {
      for (Course i in allCourses) {
        s1 += (i.grade1 > 0 || i.grade1 == -3) ? i.credits : 0;
        if(i.grade1 == -3){
          dontCount += i.credits;
        }
      }
      int sum = 0;
      for (Course i in allCourses) {
        sum += (i.grade1 > 0) ? (i.grade1 * i.credits):0;
      }
      return ((s1-dontCount) != 0) ? double.parse(((sum) / (s1-dontCount)).toStringAsFixed(2)) : 0;
    } else if (selectedprofile == 2) {
      for (Course i in allCourses) {
        s1 += (i.grade2 > 0 || i.grade2==-3) ? i.credits :0;
        if(i.grade2 == -3){
          dontCount += i.credits;
        }
      }
      int sum = 0;
      for (Course i in allCourses) {
        sum += (i.grade2 > 0) ? (i.grade2 * i.credits) : 0;
      }
      return ((s1-dontCount) != 0) ? double.parse(((sum) / (s1-dontCount)).toStringAsFixed(2)) : 0;
    } else {
      return -3.0;
    }
  }

  String sgcomp(String s) {
    var allCourses = Hive.box<Course>('coursesBox').values.where(
      (course) =>
          course.sem == currentsem &&
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)),
    );
    int dontCount =0;
    int s1 = 0;
    String ans = "";
    for (Course i in allCourses) {
      s1 += (i.grade1 > 0 || i.grade1 == -3) ? i.credits : 0;
      if(i.grade1 == -3){
        dontCount += i.credits;
      }
    }
    int sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade1 > 0) ? (i.grade1 * i.credits)  : 0;
    }
    ans = ((s1-dontCount) != 0) ? ((sum) / (s1-dontCount)).toStringAsFixed(2) : "0";
    ans += ' ';
    s1 = 0;
    dontCount=0;
    for (Course i in allCourses) {
      s1 += (i.grade2 > 0 || i.grade2 == -3) ? i.credits : 0;
      if(i.grade2 == -3){
        dontCount += i.credits;
      }
    }
    sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade2 > 0) ? (i.grade2 * i.credits) :0;
    }
    return ans + (((s1-dontCount) != 0) ? ((sum) / (s1-dontCount)).toStringAsFixed(2) : "0");
  }

  double cgcalc() {
    var allCourses = Hive.box<Course>('coursesBox').values.where(
      (course) =>
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)),
    );
    int dontCount =0;
    int s1 = 0;
    if (selectedprofile == 1) {
      for (Course i in allCourses) {
        s1 += (i.grade1 > 0 || i.grade1==-3) ? i.credits : 0;
        if(i.grade1 == -3){
          dontCount += i.credits;
        }
      }
      int sum = 0;
      for (Course i in allCourses) {
        sum += (i.grade1 > 0) ? (i.grade1 * i.credits) : 0;
      }
      return ((s1-dontCount) != 0) ? double.parse(((sum) / (s1-dontCount)).toStringAsFixed(2)) : 0;
    }
    else if (selectedprofile == 2) {
      for (Course i in allCourses) {
        s1 += (i.grade2 > 0 || i.grade2 == -3) ? i.credits : 0;
        if(i.grade2 == -3){
          dontCount += i.credits;
        }
      }
      int sum = 0;
      for (Course i in allCourses) {
        sum += (i.grade2 > 0) ? (i.grade2 * i.credits) :0;
      }
      return ((s1-dontCount) != 0) ? double.parse(((sum) / (s1-dontCount)).toStringAsFixed(2)) : 0;
    }
    return -3.0;
  }

  String cgcomp() {
    var allCourses = Hive.box<Course>('coursesBox').values.where(
      (course) =>
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)),
    );
    String ans = "";
    int dontCount =0;
    int s1 = 0;
    for (Course i in allCourses) {
      s1 += (i.grade1 > 0 || i.grade1 == -3) ? i.credits : 0;
      if(i.grade1 == -3){
        dontCount += i.credits;
      }
    }
    int sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade1 >0) ? (i.grade1 * i.credits) :0;
    }
    ans = ((s1-dontCount) != 0) ? ((sum) / (s1-dontCount)).toStringAsFixed(2) : "0";
    ans += " ";
    s1 = 0;
    dontCount =0;
    for (Course i in allCourses) {
      s1 += (i.grade2 >0 || i.grade2 == -3) ? i.credits : 0;
      if(i.grade2 == -3){
        dontCount += i.credits;
      }
    }
    sum = 0;
    for (Course i in allCourses) {
      sum += (i.grade2 >0) ? (i.grade2 * i.credits) : 0;
    }
    return ans + (((s1 - dontCount) != 0) ? ((sum) / (s1-dontCount)).toStringAsFixed(2) : "0");
  }

  void sort(List<Course> sitems) {
    if (selectedprofile == 1) {
      if (currentsort == "Sort by Credits(Asc)") {
        sitems.sort((a, b) => a.credits.compareTo(b.credits));
      } else if (currentsort == "Sort by Credits(Des)") {
        sitems.sort((a, b) => b.credits.compareTo(a.credits));
      } else if (currentsort == "Sort by Grades(Des)") {
        sitems.sort((a, b) => b.grade1.compareTo(a.grade1));
      } else if (currentsort == "Sort by Grades(Asc)") {
        sitems.sort((a, b) => a.grade1.compareTo(b.grade1));
      }
    } else if (selectedprofile == 2) {
      if (currentsort == "Sort by Credits(Asc)") {
        sitems.sort((a, b) => a.credits.compareTo(b.credits));
      } else if (currentsort == "Sort by Credits(Des)") {
        sitems.sort((a, b) => b.credits.compareTo(a.credits));
      } else if (currentsort == "Sort by Grades(Des)") {
        sitems.sort((a, b) => b.grade2.compareTo(a.grade2));
      } else if (currentsort == "Sort by Grades(Asc)") {
        sitems.sort((a, b) => a.grade2.compareTo(b.grade2));
      }
    }
  }

  void electiveSetter(){
    if(addcourse=="HSS" || addcourse=="GS" || huel.contains(addcourse + " " + addcourseid)){
      selectedelective = "Humanity Elective";
    }
    else if(del[selecteddiscipline.substring(2,4)]!.contains(addcourse + " " + addcourseid)){
      selectedelective = "Disciplinary Elective2";
    }
    else if(del[selecteddiscipline.substring(0,2)]!.contains(addcourse + " " + addcourseid)){
      selectedelective = "Disciplinary Elective1";
    }
    else if(nonelist.contains(addcourse + " " + addcourseid)){
      selectedelective = "CDCN";
    }
    else{
      selectedelective = "Open Elective";
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Course> sitems = items.toList();
    sort(sitems);
    setdis();
    setsort();
    setsem();
    setprof();
    settheme();
    setnavcolor();
    name1 =
        mcourselist
            .firstWhere(
              (course) => course.id == ("$addcourse $addcourseid"),
              orElse: () => Mastercourselist(id: '', title: '', credits: 0),
            )
            .title;

    credits1 =
        mcourselist
            .firstWhere(
              (course) => course.id == ("$addcourse $addcourseid"),
              orElse: () => Mastercourselist(id: '', title: '', credits: 0),
            )
            .credits;
    sgpa = sgcalc(currentsem);
    cgpa = cgcalc();
    scred1 = 0;
    scred2 = 0;
    ccred1 = 0;
    ccred2 = 0;
    for (Course i in Hive.box<Course>('coursesBox').values.where(
      (course) =>
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)) &&
          course.sem == currentsem,
    )) {
      scred1 += (i.grade1 < 0 && !(i.grade1==-3)) ? 0 : i.credits;
      scred2 += (i.grade2 < 0 && !(i.grade2==-3)) ? 0 : i.credits;
    }

    for (Course i in Hive.box<Course>('coursesBox').values.where(
      (course) =>
          (course.discipline == selecteddiscipline.substring(0, 2) ||
              course.discipline == selecteddiscipline.substring(2, 4)),
    )) {
      ccred1 += (i.grade1 < 0 && !(i.grade1==-3)) ? 0 : i.credits;
      ccred2 += (i.grade2 < 0 && !(i.grade2==-3)) ? 0 : i.credits;
    }
    var wid = MediaQuery.of(context).size.width;
    var hei = MediaQuery.of(context).size.height;
    if (kIsWeb && hei < wid) {
      wid = hei * 17.9 / 18;
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            thm.backcolor,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (MediaQuery.of(context).size.width - wid) / 2,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color:
                            (MediaQuery.of(context).size.width > wid)
                                ? (thm.backcolor)
                                : (thm.backcolor),
                        width: 1,
                      ),
                      horizontal: BorderSide(
                        color:
                            (MediaQuery.of(context).size.width > wid)
                                ? (thm.backcolor)
                                : (thm.backcolor),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      if (!kIsWeb)
                        if (Platform.isAndroid) SizedBox(height: 40),
                      Row(
                        children: [
                          SizedBox(width: 20),
                          Transform.scale(
                            alignment: Alignment.centerLeft,
                            scale: 0.75,
                            child: DropdownMenu(
                                 enableSearch: false,
                              enableFilter: false,
                              initialSelection: currentsem,
                              onSelected: (String? value) {
                                setState(() {
                                  currentsem = value!;
                                  sgpa = sgcalc(value);
                                  cgpa = cgcalc();
                                });
                              },
                              textAlign: TextAlign.center,
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                                color:
                                    thm.textcolor,
                              ),
                              inputDecorationTheme: InputDecorationTheme(
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color:
                                    thm.bordcolor,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                      thm.bordcolor,
                                      width: 1,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                      thm.bordcolor,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                menuStyle: MenuStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                    thm.backcolor,
                                  ),
                                ),
                                dropdownMenuEntries:
                                    sems.map((id)=> DropdownMenuEntry(value: id, label: id,style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),)).toList() + ((selecteddiscipline.startsWith("B"))?[DropdownMenuEntry(value: "ST 2",label: "ST 2",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),),DropdownMenuEntry(value: "5 - 1",label: "5 - 1",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),),DropdownMenuEntry(value: "5 - 2",label: "5 - 2",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),)]:[]),
                            ),
                          ),
                          Spacer(flex: 1),
                          Row(
                            children: [
                                    // if(kIsWeb)
                                    //   SizedBox(height: 35,width: 70,child:
                                    //   FloatingActionButton(
                                    //   elevation: 0,
                                    //   focusElevation: 0,
                                    //   hoverElevation: 0,
                                    //   highlightElevation: 0,
                                    //   disabledElevation: 0,
                                    //   backgroundColor: Colors.transparent,
                                    //   shape: RoundedRectangleBorder(
                                    //       borderRadius: BorderRadius.circular(20),
                                    //     side: BorderSide(color: thm.iconcolor)
                                    //   ),
                                    //   child: Text(
                                    //     "Install",style: TextStyle(
                                    //     color:
                                    //     thm.iconcolor,
                                    //     fontFamily: 'Montserrat',
                                    //     fontSize: 14,
                                    //   ),
                                    //   ),
                                    //       onPressed: () async {
                                    //         final ua = html.window.navigator
                                    //             .userAgent.toLowerCase();
                                    //         if (ua.contains('android')) {
                                    //           await launchUrl(
                                    //             Uri.parse(
                                    //                 'https://play.google.com/store/apps/details?id=com.srijen.cgpa_calculator'),
                                    //           );
                                    //         }
                                    //         else {
                                    //           try {
                                    //             js.context.callMethod(
                                    //                 'promptInstall');
                                    //           }
                                    //           catch (e) {
                                    //             if (ua.contains('ios') ||
                                    //                 ua.contains('ipad') ||
                                    //                 ua.contains('iphone')) {
                                    //               ScaffoldMessenger
                                    //                   .of(context)
                                    //                   .showSnackBar(
                                    //                 SnackBar(
                                    //                   content: Text(
                                    //                     "Click on Share => Add to Home Screen => Add",
                                    //                     style: TextStyle(
                                    //                       fontFamily: "Montserrat",
                                    //                       fontWeight: FontWeight
                                    //                           .normal,
                                    //                       fontSize: 16,
                                    //                     ),
                                    //                   ),
                                    //                   duration: Duration(
                                    //                       seconds: 4),
                                    //                 ),
                                    //               );
                                    //             }
                                    //             else if (ua.contains('win') ||
                                    //                 ua.contains('mac') ||
                                    //                 ua.contains('linux')) {
                                    //               ScaffoldMessenger
                                    //                   .of(context)
                                    //                   .showSnackBar(
                                    //                 SnackBar(
                                    //                   content: Text(
                                    //                     "Click on Settings => Cast, Save and Share => Install Page as app",
                                    //                     style: TextStyle(
                                    //                       fontFamily: "Montserrat",
                                    //                       fontWeight: FontWeight
                                    //                           .normal,
                                    //                       fontSize: 16,
                                    //                     ),
                                    //                   ),
                                    //                   duration: Duration(
                                    //                       seconds: 4),
                                    //                 ),
                                    //               );
                                    //             }
                                    //             else {
                                    //               ScaffoldMessenger
                                    //                   .of(context)
                                    //                   .showSnackBar(
                                    //                 SnackBar(
                                    //                   content: Text(
                                    //                     "Click on Share => Add to Home Screen => Add",
                                    //                     style: TextStyle(
                                    //                       fontFamily: "Montserrat",
                                    //                       fontWeight: FontWeight
                                    //                           .normal,
                                    //                       fontSize: 16,
                                    //                     ),
                                    //                   ),
                                    //                   duration: Duration(
                                    //                       seconds: 4),
                                    //                 ),
                                    //               );
                                    //             }
                                    //           }
                                    //         }
                                    //       }
                                    //   ),),
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(3.1416),
                                child: Transform.scale(
                                  scale: 1.2,
                                  child: FloatingActionButton(
                                    elevation: 0,
                                    focusElevation: 0,
                                    hoverElevation: 0,
                                    highlightElevation: 0,
                                    disabledElevation: 0,
                                    backgroundColor: Colors.transparent,
                                    shape: CircleBorder(),
                                    child: Icon(
                                      Icons.insert_chart_rounded,
                                      color:
                                          thm.iconcolor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (context) => Analytics(
                                                ),
                                          ),
                                        );
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Transform.scale(
                                alignment: Alignment.centerRight,
                                scale: 1.2,
                                child: FloatingActionButton(
                                  key: ValueKey("settings"),
                                  elevation: 0,
                                  focusElevation: 0,
                                  hoverElevation: 0,
                                  highlightElevation: 0,
                                  disabledElevation: 0,
                                  backgroundColor: Colors.transparent,
                                  shape: CircleBorder(),
                                  child: Icon(
                                    Icons.settings_rounded,
                                    color:
                                        thm.iconcolor,
                                  ),
                                  onPressed: () async {
                                    erase = 0;
                                    await Navigator.of(context)
                                        .push(
                                          MaterialPageRoute(
                                            builder: (context) => Settings(),
                                          ),
                                        )
                                        .then((value) async {
                                          selected_theme = selected_theme;
                                          thm = themes.firstWhere((theme) => theme.theme == selected_theme);
                                          //await settheme();
                                          profile1n = profile1n;
                                          profile2n = profile2n;
                                          //await setprof();
                                          currentsem = currentsem;
                                          batch=batch;
                                          selecteddiscipline =selecteddiscipline;
                                          await setdis();
                                          await initializeCourses();
                                          setnavcolor();
                                          setState(() {
                                            profile1n = profile1n;
                                            profile2n = profile2n;
                                            currentsem = currentsem;
                                            batch=batch;
                                            selecteddiscipline =
                                                selecteddiscipline;
                                            thm = themes.firstWhere((theme) => theme.theme == selected_theme);
                                          });
                                        });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (selectedprofile == 3)
                        Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Comparing $profile1n and $profile2n grades",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        thm.textcolor,
                                    fontFamily: 'Montserrat',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Card(
                                    color:
                                        thm.cardcolor,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  "SGPA",
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                ),
                                                Text(
                                                  "Credits (S)",
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  "CGPA",
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                ),
                                                Text(
                                                  "Credits (C)",
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            width: wid * 0.260,
                                            //0.229,
                                            child: IntrinsicHeight(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceEvenly,
                                                      children: [
                                                        Text(
                                                          (sgcomp(
                                                                    currentsem,
                                                                  ).split(
                                                                    " ",
                                                                  )[0] !=
                                                                  "0")
                                                              ? sgcomp(
                                                                currentsem,
                                                              ).split(" ")[0]
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 18,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                        Text(
                                                          ("$scred1" != "0")
                                                              ? "$scred1"
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 14,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                        SizedBox(height: 12),
                                                        Text(
                                                          (cgcomp().split(
                                                                    " ",
                                                                  )[0] !=
                                                                  "0")
                                                              ? cgcomp().split(
                                                                " ",
                                                              )[0]
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 18,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                        Text(
                                                          ("$ccred1" != "0")
                                                              ? "$ccred1"
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 14,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  FractionallySizedBox(
                                                    heightFactor: 0.98,
                                                    child: Container(
                                                      width: 1,
                                                      color:
                                                          thm
                                                              .sepcolor,
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 2,
                                                          ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceEvenly,
                                                      children: [
                                                        Text(
                                                          (sgcomp(
                                                                    currentsem,
                                                                  ).split(
                                                                    " ",
                                                                  )[1] !=
                                                                  "0")
                                                              ? sgcomp(
                                                                currentsem,
                                                              ).split(" ")[1]
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 18,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                        Text(
                                                          ("$scred2" != "0")
                                                              ? "$scred2"
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 14,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                        SizedBox(height: 12),
                                                        Text(
                                                          (cgcomp().split(
                                                                    " ",
                                                                  )[1] !=
                                                                  "0")
                                                              ? cgcomp().split(
                                                                " ",
                                                              )[1]
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 18,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                        Text(
                                                          ("$ccred2" != "0")
                                                              ? "$ccred2"
                                                              : "-",
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontSize: 14,
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (selectedprofile != 3)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 6),
                                  SizedBox(
                                    width: min(wid * 0.20, 120),
                                    child: Row(
                                      children: [
                                        Text(
                                          "SGPA",
                                          style: TextStyle(
                                            color:
                                                thm
                                                    .textcolor,
                                            fontSize: 18,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 17),
                                  SizedBox(
                                    width: min(wid * 0.20, 120),
                                    child: Row(
                                      children: [
                                        Text(
                                          "Credits",
                                          style: TextStyle(
                                            color:
                                                thm
                                                    .textcolor,
                                            fontSize: 15,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (selectedprofile != 3)
                                        ? "$sgpa"
                                        : sgcomp(currentsem),
                                    style: TextStyle(
                                      color:
                                          thm.textcolor,
                                      fontSize:
                                          (selectedprofile != 3) ? 34 : 28,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    (selectedprofile == 1)
                                        ? "$scred1"
                                        : (selectedprofile == 2)
                                        ? "$scred2"
                                        : "$scred1,$scred2",
                                    style: TextStyle(
                                      color:
                                          thm.textcolor,
                                      fontSize: 22,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(flex: 1),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(height: 6),
                                  SizedBox(
                                    width: min(wid * 0.20, 120),
                                    child: Row(
                                      children: [
                                        Text(
                                          "CGPA",
                                          style: TextStyle(
                                            color:
                                                thm
                                                    .textcolor,
                                            fontSize: 18,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 17),
                                  SizedBox(
                                    width: min(wid * 0.20, 120),
                                    child: Row(
                                      children: [
                                        Text(
                                          "Credits",
                                          style: TextStyle(
                                            color:
                                                thm
                                                    .textcolor,
                                            fontSize: 15,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (selectedprofile != 3) ? "$cgpa" : cgcomp(),
                                    style: TextStyle(
                                      color:
                                          thm.textcolor,
                                      fontSize:
                                          (selectedprofile != 3) ? 34 : 28,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    (selectedprofile == 1)
                                        ? "$ccred1"
                                        : (selectedprofile == 2)
                                        ? "$ccred2"
                                        : "$ccred1,$ccred2",
                                    style: TextStyle(
                                      color:
                                          thm.textcolor,
                                      fontSize: 22,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: hei * 0.01),
                      if (selectedprofile != 3)
                        Row(
                          children: [
                            SizedBox(width: wid * 0.04),
                            SizedBox(
                              height: hei * 0.05,
                              width: wid * 0.54,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color:
                                        thm.bordcolor,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearched = false;
                                    _isCardOpen = true;
                                  });
                                },
                                child: Text(
                                  "Add Courses",
                                  style: TextStyle(
                                    color:
                                        thm.highcolor,
                                    fontSize: 16,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: wid * 0.03),
                            Transform.scale(
                              scale: 1,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  inputDecorationTheme: InputDecorationTheme(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 8,
                                    ),
                                    constraints: BoxConstraints.tightFor(
                                      height: hei * 0.05,
                                    ),
                                  ),
                                ),
                                child: DropdownMenu(
                                  width: wid * 0.36,
                                  onSelected: (value) {
                                    setState(() {
                                      currentsort = value!;
                                      sort(sitems);
                                    });
                                  },
                                  initialSelection: currentsort,
                                  textStyle: TextStyle(
                                    fontSize: (selectedprofile != 3) ? 12 : 0,
                                    fontWeight: FontWeight.normal,
                                    fontFamily: "Montserrat",
                                    color:
                                        thm.textcolor,
                                  ),
                                  inputDecorationTheme: InputDecorationTheme(
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            thm.bordcolor,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            thm.bordcolor,
                                        width: 1,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            thm.bordcolor,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  menuStyle: MenuStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                      thm.backcolor,
                                    ),
                                  ),
                                  dropdownMenuEntries: [
                                    DropdownMenuEntry(
                                      value: "Sort by Credits(Asc)",
                                      enabled: (selectedprofile != 3),
                                      leadingIcon: Icon(Icons.keyboard_arrow_down_outlined, color: thm.textcolor,),
                                      label: "Asc Credits",
                                      style: MenuItemButton.styleFrom(
                                        textStyle: TextStyle(
                                          fontFamily: 'Montserrat',
                                        ),
                                        foregroundColor:
                                            thm.textcolor,
                                      ),
                                    ),
                                    DropdownMenuEntry(
                                      value: "Sort by Credits(Des)",
                                      enabled: (selectedprofile != 3),

                                      leadingIcon: Icon(Icons.keyboard_arrow_up_outlined, color: thm.textcolor,),
                                      label: "Desc Credits",
                                      style: MenuItemButton.styleFrom(
                                        textStyle: TextStyle(
                                          fontFamily: 'Montserrat',
                                        ),
                                        foregroundColor:
                                            thm.textcolor,
                                      ),
                                    ),
                                    DropdownMenuEntry(
                                      enabled: (selectedprofile != 3),
                                      value: "Sort by Grades(Asc)",

                                      leadingIcon: Icon(Icons.keyboard_arrow_down_outlined, color: thm.textcolor,),
                                      label: "Asc Grades",
                                      style: MenuItemButton.styleFrom(
                                        textStyle: TextStyle(
                                          fontFamily: 'Montserrat',
                                        ),
                                        foregroundColor:
                                            thm.textcolor,
                                      ),
                                    ),
                                    DropdownMenuEntry(
                                      enabled: (selectedprofile != 3),
                                      value: "Sort by Grades(Des)",

                                      leadingIcon: Icon(Icons.keyboard_arrow_up_outlined, color: thm.textcolor,),
                                      label: "Desc Grades",
                                      style: MenuItemButton.styleFrom(
                                        textStyle: TextStyle(
                                          fontFamily: 'Montserrat',
                                        ),
                                        foregroundColor:
                                            thm.textcolor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: wid * 0.02),
                          ],
                        ),
                      SizedBox(height: hei * 0.01),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragEnd: (details) {
                            setState(() {
                              if (details.primaryVelocity! < 0 &&
                                  selectedprofile < 3) {
                                selectedprofile += 1;
                                _isrightswipe = true;
                              } else if (details.primaryVelocity! > 0 &&
                                  selectedprofile > 1) {
                                selectedprofile -= 1;
                                _isrightswipe = false;
                              }
                            });
                          },
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 350),
                            transitionBuilder: (
                              Widget child,
                              Animation<double> animation,
                            ) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: Offset(
                                    (!_isrightswipe)
                                        ? (MediaQuery.of(context).size.width >
                                                wid)
                                            ? -0.07
                                            : -1
                                        : (MediaQuery.of(context).size.width >
                                            wid)
                                        ? 0.07
                                        : 1,
                                    0.0,
                                  ),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              );
                            },
                            child: ListView.builder(
                              key: ValueKey(selectedprofile),
                              padding: EdgeInsets.only(top: 0),
                              itemCount: sitems.length,
                              itemBuilder: (BuildContext context, int index) {
                                return (selectedprofile != 4)
                                    ? Card(
                                      color:
                                          thm.cardcolor,
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ListTile(
                                        title: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Text(
                                            sitems[index].title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.normal,
                                              color:
                                                  thm
                                                      .textcolor,
                                            ),
                                          ),
                                        ),
                                        subtitle: Text(
                                          sitems[index].id,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.normal,
                                            color:
                                                thm
                                                    .textcolor,
                                          ),
                                        ),
                                        leading:
                                            (selectedprofile != 3)
                                                ? Stack(
                                                  children: [
                                                    SizedBox(
                                                      width: wid * 0.13,
                                                      child: Container(
                                                        color:
                                                            Colors.transparent,
                                                        child: Row(
                                                          children: [
                                                            Column(
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      sitems[index]
                                                                          .credits
                                                                          .toString(),
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            21.5,
                                                                        fontFamily:
                                                                            'Montserrat',
                                                                        color:
                                                                            thm
                                                                                .textcolor,
                                                                      ),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                    ),
                                                                  ],
                                                                ),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      "Credit",
                                                                      style: TextStyle(
                                                                        fontFamily:
                                                                            'Montserrat',
                                                                        color:
                                                                            thm
                                                                                .textcolor,
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: wid * 0.132,
                                                      ),
                                                      child: Container(
                                                        width: 1,
                                                        height: 60,
                                                        color:
                                                            thm
                                                                .sepcolor,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                : null,
                                        trailing:
                                            (selectedprofile != 3)
                                                ? Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        right: wid * (0.120),
                                                      ),
                                                      child: Container(
                                                        width: 1,
                                                        height: 60,
                                                        color:
                                                            thm
                                                                .sepcolor,
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: wid * 0.035,
                                                      ),
                                                      child: Text(
                                                        (selectedprofile == 1)
                                                            ? gradecalc(
                                                              sitems[index]
                                                                  .grade1,
                                                            )
                                                            : (selectedprofile ==
                                                                2)
                                                            ? gradecalc(
                                                              sitems[index]
                                                                  .grade2,
                                                            )
                                                            : "-3",
                                                        style: TextStyle(
                                                          fontSize:
                                                              (gradecalc(
                                                                        (selectedprofile ==
                                                                                1)
                                                                            ? sitems[index].grade1
                                                                            : (selectedprofile ==
                                                                                2)
                                                                            ? sitems[index].grade2
                                                                            : -3,
                                                                      ) ==
                                                                      "CLR")
                                                                  ? 16
                                                                  : (gradecalc(
                                                                            (selectedprofile ==
                                                                                    1)
                                                                                ? sitems[index].grade1
                                                                                : (selectedprofile ==
                                                                                    2)
                                                                                ? sitems[index].grade2
                                                                                : -3,
                                                                          ) ==
                                                                          "NC" ||
                                                                      gradecalc(
                                                                            (selectedprofile ==
                                                                                    1)
                                                                                ? sitems[index].grade1
                                                                                : (selectedprofile ==
                                                                                    2)
                                                                                ? sitems[index].grade2
                                                                                : -3,
                                                                          ) ==
                                                                          "GD")
                                                                  ? 18
                                                                  : 20,
                                                          fontFamily:
                                                              "Montserrat",
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              thm
                                                                  .highcolor,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                : SizedBox(
                                                  width: wid * 0.220,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      SizedBox(
                                                        width: wid * 0.0945,
                                                        child: Text(
                                                          (((sitems[index].grade1 >
                                                                              0)
                                                                          ? gradecalc(
                                                                            sitems[index].grade1,
                                                                          )
                                                                          : "–")
                                                                      .length) ==
                                                                  2
                                                              ? (sitems[index]
                                                                          .grade1 >
                                                                      0)
                                                                  ? gradecalc(
                                                                    sitems[index]
                                                                        .grade1,
                                                                  )
                                                                  : "–" + "‎ "
                                                              : ((sitems[index]
                                                                              .grade1 >
                                                                          0)
                                                                      ? gradecalc(
                                                                        sitems[index]
                                                                            .grade1,
                                                                      )
                                                                      : "–") +
                                                                  "‎ ‎ ",

                                                          textAlign:
                                                              TextAlign.right,
                                                          style: TextStyle(
                                                            fontSize: 20,
                                                            fontFamily:
                                                                'Montserrat',
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height: 60,
                                                        color:
                                                            thm
                                                                .sepcolor,
                                                        margin:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 5,
                                                            ),
                                                      ),
                                                      SizedBox(
                                                        width: wid * 0.0945,
                                                        child: Text(
                                                          "‎" +
                                                              ((sitems[index]
                                                                          .grade2 >
                                                                      0)
                                                                  ? gradecalc(
                                                                    sitems[index]
                                                                        .grade2,
                                                                  )
                                                                  : "–"),
                                                          textAlign:
                                                              TextAlign.left,
                                                          style: TextStyle(
                                                            fontSize: 20,
                                                            fontFamily:
                                                                'Montserrat',
                                                            color:
                                                                thm
                                                                    .highcolor,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        onTap: () {
                                          setState(() {
                                            if (selectedprofile != 3) {
                                              tapid = index;
                                              addcourse =
                                                  sitems[index].id.split(
                                                    " ",
                                                  )[0];
                                              addcourseid =
                                                  sitems[index].id.split(
                                                    " ",
                                                  )[1];
                                              _isCourseCardOpen = true;
                                            }
                                          });
                                        },
                                      ),
                                    )
                                    : Padding(
                                      padding: EdgeInsets.only(
                                        left: 15,
                                        right: 15,
                                      ),
                                      child: Table(
                                        columnWidths:
                                            const <int, TableColumnWidth>{
                                              0: FlexColumnWidth(),
                                              1: FractionColumnWidth(0.13),
                                              2: FractionColumnWidth(0.13),
                                            },
                                        border: TableBorder.all(
                                          color:
                                              thm.textcolor,
                                        ),
                                        children: [
                                          TableRow(
                                            children: [
                                              Text(
                                                sitems[index].title,
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                              Text(
                                                gradecalc(sitems[index].grade1),
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                              Text(
                                                gradecalc(sitems[index].grade2),
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child:
                  _isCourseCardOpen
                      ? Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: _isCourseCardOpen ? 0.6 : 0.0,
                            duration: Duration(milliseconds: 500),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  addcourse = "AN";
                                  addcourseid = "F311";
                                  electiveSetter();
                                  dropdownid =
                                      mcourselist
                                          .where(
                                            (course) => course.id.startsWith(
                                              "AN" + ' ',
                                            ),
                                          )
                                          .map(
                                            (course) => course.id.replaceFirst(
                                              "AN" + ' ',
                                              '',
                                            ),
                                          )
                                          .toList();
                                  dropdownid.sort((a, b) => a.compareTo(b));
                                  _isCourseCardOpen = false;
                                });
                              },
                              child: Container(
                                color:
                                    thm.backcolor,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          Center(
                            child: AnimatedScale(
                              scale: _isCourseCardOpen ? 1.0 : 0.8,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              child: Card(
                                color:
                                    thm.cardcolor,
                                elevation: 40,
                                margin: EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color:
                                        thm.textcolor,
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    height: hei * 0.44,
                                    width: wid * 0.85,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Spacer(flex: 1),
                                            Text(
                                              "${sitems[tapid].id.split(" ")[0]} ",
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.normal,
                                                fontFamily: 'Montserrat',
                                                color:
                                                    thm
                                                        .textcolor,
                                              ),
                                            ),
                                            Text(
                                              sitems[tapid].id.split(" ")[1],
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.normal,
                                                fontFamily: 'Montserrat',
                                                color:
                                                    thm
                                                        .textcolor,
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                          ],
                                        ),
                                        Row(mainAxisAlignment: MainAxisAlignment.center,children: [Text(electiveFinder(sitems[tapid].elective),textAlign: TextAlign.center ,style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, fontFamily: 'Montserrat', color: thm.textcolor))]),
                                        Spacer(flex: 1),
                                        Row(
                                          children: [
                                            Spacer(flex: 1),
                                            SizedBox(height: hei * 0.1),
                                            Container(
                                              margin: EdgeInsets.only(right: 0),
                                              height: hei * 0.08,
                                              width: wid * 0.8,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      thm
                                                          .bordcolor,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),

                                              child: Center(
                                                child: Marquee(
                                                  text: "  $name1  ",
                                                  scrollAxis: Axis.horizontal,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  blankSpace: 10,
                                                  velocity: 30,
                                                  startPadding: 2.0,

                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 22,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                          ],
                                        ),
                                        Spacer(flex: 1),
                                        Row(
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: wid * 0.025,
                                              ),
                                              child: SizedBox(
                                                width: wid * 0.79,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      height: hei * 0.08,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color:
                                                              thm
                                                                  .bordcolor,
                                                          width: 1.0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          "    $credits1    ",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontFamily:
                                                                'Montserrat',
                                                            fontSize: 22,
                                                            color:
                                                                thm
                                                                    .textcolor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Spacer(flex: 1),
                                                    Theme(
                                                      data: Theme.of(
                                                        context,
                                                      ).copyWith(
                                                        inputDecorationTheme:
                                                            InputDecorationTheme(
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        8,
                                                                  ),
                                                              constraints:
                                                                  BoxConstraints.tightFor(
                                                                    height:
                                                                        double
                                                                            .infinity,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: DropdownMenu(
                                                        textStyle: TextStyle(
                                                          fontSize: 20,
                                                          fontFamily:
                                                              'Montserrat',
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          color:
                                                              thm
                                                                  .textcolor,
                                                        ),
                                                        initialSelection: gradecalc(
                                                          (selectedprofile == 1)
                                                              ? sitems[tapid]
                                                                  .grade1
                                                              : (selectedprofile ==
                                                                  2)
                                                              ? sitems[tapid]
                                                                  .grade2
                                                              : -3,
                                                        ),
                                                        inputDecorationTheme: InputDecorationTheme(
                                                          enabledBorder: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm
                                                                      .bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm
                                                                      .bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          border: OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm
                                                                      .bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                        ),
                                                        menuStyle: MenuStyle(
                                                          backgroundColor: WidgetStateProperty.all(
                                                            thm
                                                                .backcolor,
                                                          ),
                                                        ),
                                                        dropdownMenuEntries: grades.map<DropdownMenuEntry<String>>((String value) {
                                                    return DropdownMenuEntry<String>(
                                                    value: value,
                                                    label: value,
                                                      style: MenuItemButton.styleFrom(
                                                        textStyle: TextStyle(
                                                          fontFamily:
                                                          'Montserrat',
                                                        ),
                                                        foregroundColor:
                                                        thm
                                                            .textcolor,
                                                      ),

                                                    );
                                                    }).toList(),
                                                        onSelected: (value) async{
                                                          _isGradeChanged =
                                                              true;
                                                          selectedgrade =
                                                              reversegradecalc(
                                                                value!,
                                                              );

                                                            if (selectedprofile !=
                                                                3) {
                                                              if (_isGradeChanged) {
                                                                Course
                                                                tempcourse = sitems
                                                                    .lastWhere(
                                                                      (course) =>
                                                                  course
                                                                      .id ==
                                                                      "$addcourse $addcourseid",
                                                                );
                                                                await removeCourseById(
                                                                "$addcourse $addcourseid",
                                                                );
                                                                await Future.delayed(
                                                                  Duration(
                                                                    milliseconds:
                                                                    20,
                                                                  ),
                                                                );
                                                                if (selectedprofile ==
                                                                    1) {
                                                                  await addOrUpdateCourse(
                                                                  Course(
                                                                    elective:
                                                                    tempcourse
                                                                        .elective,
                                                                    title:
                                                                    tempcourse
                                                                        .title,
                                                                    sem:
                                                                    currentsem,
                                                                    id:
                                                                    "$addcourse $addcourseid",
                                                                    discipline:
                                                                    tempcourse
                                                                        .discipline,
                                                                    grade1:
                                                                    selectedgrade,
                                                                    grade2:
                                                                    tempcourse
                                                                        .grade2,
                                                                    credits:
                                                                    tempcourse
                                                                        .credits,
                                                                  ),
                                                                  );
                                                                  await Future.delayed(
                                                                    Duration(
                                                                      milliseconds:
                                                                      50,
                                                                    ),
                                                                  );
                                                                  selectedelective = "None";
                                                                } else if (selectedprofile ==
                                                                    2) {
                                                                  await addOrUpdateCourse(
                                                                  Course(
                                                                    elective:
                                                                    tempcourse
                                                                        .elective,
                                                                    title:
                                                                    tempcourse
                                                                        .title,
                                                                    sem:
                                                                    currentsem,
                                                                    id:
                                                                    "$addcourse $addcourseid",
                                                                    discipline:
                                                                    ((selecteddiscipline.substring(
                                                                      0,
                                                                      2,
                                                                    ) !=
                                                                        "--")
                                                                        ? selecteddiscipline.substring(
                                                                      0,
                                                                      2,
                                                                    )
                                                                        : selecteddiscipline.substring(
                                                                      2,
                                                                      4,
                                                                    )),
                                                                    grade1:
                                                                    tempcourse
                                                                        .grade1,
                                                                    grade2:
                                                                    selectedgrade,
                                                                    credits:
                                                                    tempcourse
                                                                        .credits,
                                                                  ),
                                                                  );
                                                                  selectedelective = "None";
                                                                  await Future.delayed(
                                                                    Duration(
                                                                      milliseconds:
                                                                      50,
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            } else {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    style: TextStyle(
                                                                      fontFamily:
                                                                      "Montserrat",
                                                                      fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                      fontSize: 16,
                                                                    ),
                                                                    "Select Profile First",
                                                                  ),
                                                                  duration:
                                                                  Duration(
                                                                    seconds: 3,
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                            setState(() {
                                                              if (_isGradeChanged) {
                                                                selecteddiscipline =
                                                                    selecteddiscipline;
                                                                batch=batch;
                                                                currentsem =
                                                                    currentsem;
                                                                addcourse = "AN";
                                                                addcourseid =
                                                                "F311";
                                                                electiveSetter();
                                                                dropdownid =
                                                                    mcourselist
                                                                        .where(
                                                                          (
                                                                          course,
                                                                          ) => course
                                                                          .id
                                                                          .startsWith(
                                                                        "AN" +
                                                                            ' ',
                                                                      ),
                                                                    )
                                                                        .map(
                                                                          (
                                                                          course,
                                                                          ) => course
                                                                          .id
                                                                          .replaceFirst(
                                                                        "AN" +
                                                                            ' ',
                                                                        '',
                                                                      ),
                                                                    )
                                                                        .toList();
                                                                dropdownid.sort(
                                                                      (a, b) => a
                                                                      .compareTo(b),
                                                                );
                                                                sort(sitems);
                                                                _isCourseCardOpen =
                                                                false;
                                                                _isGradeChanged =
                                                                false;
                                                              } else {
                                                                sort(sitems);
                                                                _isCourseCardOpen =
                                                                false;
                                                              }
                                                              selectedgrade = 10;
                                                            });

                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Spacer(flex: 1),
                                        Row(
                                          children: [
                                            Spacer(flex: 1),
                                            SizedBox(
                                              height: hei * 0.08,
                                              width: wid * 0.8,
                                              child: Row(
                                                children: [
                                                  // Container(
                                                  //   width: wid * 0.57,
                                                  //   height: double.infinity,
                                                  //   child: FloatingActionButton(
                                                  //     backgroundColor:
                                                  //         thm
                                                  //             .butcolor,
                                                  //     elevation: 2,
                                                  //     child: Text(
                                                  //       "Update Course",
                                                  //       style: TextStyle(
                                                  //         fontFamily:
                                                  //             'Montserrat',
                                                  //         fontWeight:
                                                  //             FontWeight.normal,
                                                  //         fontSize: 22,
                                                  //         color:
                                                  //             thm
                                                  //                 .highcolor,
                                                  //       ),
                                                  //     ),
                                                  //     onPressed: () async {
                                                  //       if (selectedprofile !=
                                                  //           3) {
                                                  //         if (_isGradeChanged) {
                                                  //           Course
                                                  //           tempcourse = sitems
                                                  //               .firstWhere(
                                                  //                 (course) =>
                                                  //                     course
                                                  //                         .id ==
                                                  //                     "$addcourse $addcourseid",
                                                  //               );
                                                  //           await removeCourseById(
                                                  //             "$addcourse $addcourseid",
                                                  //           );
                                                  //           await Future.delayed(
                                                  //             Duration(
                                                  //               milliseconds:
                                                  //                   20,
                                                  //             ),
                                                  //           );
                                                  //           if (selectedprofile ==
                                                  //               1) {
                                                  //             await addOrUpdateCourse(
                                                  //               Course(
                                                  //                 elective:
                                                  //                     tempcourse
                                                  //                         .elective,
                                                  //                 title:
                                                  //                     tempcourse
                                                  //                         .title,
                                                  //                 sem:
                                                  //                     currentsem,
                                                  //                 id:
                                                  //                     "$addcourse $addcourseid",
                                                  //                 discipline:
                                                  //                     tempcourse
                                                  //                         .discipline,
                                                  //                 grade1:
                                                  //                     selectedgrade,
                                                  //                 grade2:
                                                  //                     tempcourse
                                                  //                         .grade2,
                                                  //                 credits:
                                                  //                     tempcourse
                                                  //                         .credits,
                                                  //               ),
                                                  //             );
                                                  //             await Future.delayed(
                                                  //               Duration(
                                                  //                 milliseconds:
                                                  //                     20,
                                                  //               ),
                                                  //             );
                                                  //             selectedelective = "None";
                                                  //           } else if (selectedprofile ==
                                                  //               2) {
                                                  //             await addOrUpdateCourse(
                                                  //               Course(
                                                  //                 elective:
                                                  //                     tempcourse
                                                  //                         .elective,
                                                  //                 title:
                                                  //                     tempcourse
                                                  //                         .title,
                                                  //                 sem:
                                                  //                     currentsem,
                                                  //                 id:
                                                  //                     "$addcourse $addcourseid",
                                                  //                 discipline:
                                                  //                     ((selecteddiscipline.substring(
                                                  //                               0,
                                                  //                               2,
                                                  //                             ) !=
                                                  //                             "--")
                                                  //                         ? selecteddiscipline.substring(
                                                  //                           0,
                                                  //                           2,
                                                  //                         )
                                                  //                         : selecteddiscipline.substring(
                                                  //                           2,
                                                  //                           4,
                                                  //                         )),
                                                  //                 grade1:
                                                  //                     tempcourse
                                                  //                         .grade1,
                                                  //                 grade2:
                                                  //                     selectedgrade,
                                                  //                 credits:
                                                  //                     tempcourse
                                                  //                         .credits,
                                                  //               ),
                                                  //             );
                                                  //             selectedelective = "None";
                                                  //             await Future.delayed(
                                                  //               Duration(
                                                  //                 milliseconds:
                                                  //                     20,
                                                  //               ),
                                                  //             );
                                                  //           }
                                                  //         }
                                                  //       } else {
                                                  //         ScaffoldMessenger.of(
                                                  //           context,
                                                  //         ).showSnackBar(
                                                  //           SnackBar(
                                                  //             content: Text(
                                                  //               style: TextStyle(
                                                  //                 fontFamily:
                                                  //                     "Montserrat",
                                                  //                 fontWeight:
                                                  //                     FontWeight
                                                  //                         .normal,
                                                  //                 fontSize: 16,
                                                  //               ),
                                                  //               "Select Profile First",
                                                  //             ),
                                                  //             duration:
                                                  //                 Duration(
                                                  //                   seconds: 3,
                                                  //                 ),
                                                  //           ),
                                                  //         );
                                                  //       }
                                                  //       setState(() {
                                                  //         if (_isGradeChanged) {
                                                  //           selecteddiscipline =
                                                  //               selecteddiscipline;
                                                  //           currentsem =
                                                  //               currentsem;
                                                  //           addcourse = "AN";
                                                  //           addcourseid =
                                                  //               "F311";
                                                  //           electiveSetter();
                                                  //           dropdownid =
                                                  //               mcourselist
                                                  //                   .where(
                                                  //                     (
                                                  //                       course,
                                                  //                     ) => course
                                                  //                         .id
                                                  //                         .startsWith(
                                                  //                           "AN" +
                                                  //                               ' ',
                                                  //                         ),
                                                  //                   )
                                                  //                   .map(
                                                  //                     (
                                                  //                       course,
                                                  //                     ) => course
                                                  //                         .id
                                                  //                         .replaceFirst(
                                                  //                           "AN" +
                                                  //                               ' ',
                                                  //                           '',
                                                  //                         ),
                                                  //                   )
                                                  //                   .toList();
                                                  //           dropdownid.sort(
                                                  //             (a, b) => a
                                                  //                 .compareTo(b),
                                                  //           );
                                                  //           sort(sitems);
                                                  //           _isCourseCardOpen =
                                                  //               false;
                                                  //           _isGradeChanged =
                                                  //               false;
                                                  //         } else {
                                                  //           sort(sitems);
                                                  //           _isCourseCardOpen =
                                                  //               false;
                                                  //         }
                                                  //         selectedgrade = 10;
                                                  //       });
                                                  //     },
                                                  //   ),
                                                  // ),
                                                  Spacer(flex: 1),
                                                  Container(
                                                    height: double.infinity,
                                                    width: wid * 0.20,
                                                    child: OutlinedButton(
                                                      style: OutlinedButton.styleFrom(
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                14,
                                                              ),
                                                        ),
                                                        foregroundColor:
                                                            Colors.red,
                                                        side: BorderSide(
                                                          color: Colors.red,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Transform.scale(
                                                        scale: 2,
                                                        child: Icon(Icons.delete_outline_rounded)
                                                        // Image.asset(
                                                        //   'images/trash.png',
                                                        //   color: Colors.red,
                                                        // ),
                                                      ),

                                                      onPressed: () async {
                                                        await removeCourseById(
                                                          "$addcourse $addcourseid",
                                                        );
                                                        await Future.delayed(
                                                          Duration(
                                                            milliseconds: 20,
                                                          ),
                                                        );
                                                        setState(() {
                                                          currentsem =
                                                              currentsem;
                                                          selecteddiscipline =
                                                              selecteddiscipline;
                                                          batch-batch;
                                                          addcourse = "AN";
                                                          addcourseid = "F311";
                                                          electiveSetter();
                                                          dropdownid =
                                                              mcourselist
                                                                  .where(
                                                                    (
                                                                      course,
                                                                    ) => course
                                                                        .id
                                                                        .startsWith(
                                                                          "AN" +
                                                                              ' ',
                                                                        ),
                                                                  )
                                                                  .map(
                                                                    (
                                                                      course,
                                                                    ) => course
                                                                        .id
                                                                        .replaceFirst(
                                                                          "AN" +
                                                                              ' ',
                                                                          '',
                                                                        ),
                                                                  )
                                                                  .toList();
                                                          dropdownid.sort(
                                                            (a, b) =>
                                                                a.compareTo(b),
                                                          );
                                                          sort(sitems);
                                                          _isCourseCardOpen =
                                                              false;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : SizedBox.shrink(),
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child:
                  _isCardOpen
                      ? Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: _isCardOpen ? 0.6 : 0.0,
                            duration: Duration(milliseconds: 500),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  addcourse = "AN";
                                  addcourseid = "F311";
                                  electiveSetter();
                                  dropdownid =
                                      mcourselist
                                          .where(
                                            (course) => course.id.startsWith(
                                              "AN" + ' ',
                                            ),
                                          )
                                          .map(
                                            (course) => course.id.replaceFirst(
                                              "AN" + ' ',
                                              '',
                                            ),
                                          )
                                          .toList();
                                  dropdownid.sort((a, b) => a.compareTo(b));
                                  _isCardOpen = false;
                                });
                              },
                              child: Container(
                                color:
                                    thm.backcolor,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          Center(
                            child: AnimatedScale(
                              scale: _isCardOpen ? 1.0 : 0.8,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              child: Card(
                                color:
                                    thm.backcolor,
                                elevation: 40,
                                margin: EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color:
                                        thm.textcolor,
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(wid * 0.025),
                                  child: SizedBox(
                                    height: hei * 0.50,
                                    width: wid * 0.85,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: wid * 0.34,
                                              child: DropdownMenu(
                                                initialSelection:
                                                    (_isSearched)
                                                        ? addcourse
                                                        : "AN",
                                                textStyle: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.normal,
                                                  color:
                                                      thm
                                                          .textcolor,
                                                ),
                                                onSelected: (value) {
                                                  setState(() {
                                                    addcourse = value!;
                                                    electiveSetter();
                                                    dropdownid =
                                                        mcourselist
                                                            .where(
                                                              (course) => course
                                                                  .id
                                                                  .startsWith(
                                                                    '$value ',
                                                                  ),
                                                            )
                                                            .map(
                                                              (course) => course
                                                                  .id
                                                                  .replaceFirst(
                                                                    '$value ',
                                                                    '',
                                                                  ),
                                                            )
                                                            .toList();
                                                    dropdownid.sort(
                                                      (a, b) => a.compareTo(b),
                                                    );
                                                    addcourseid = dropdownid[0];
                                                    electiveSetter();
                                                  });
                                                },
                                                inputDecorationTheme: InputDecorationTheme(
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                menuStyle: MenuStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm
                                                            .backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries:
                                                    depts
                                                        .map(
                                                          (id) => DropdownMenuEntry(
                                                            value: id,
                                                            label: id,
                                                            style: MenuItemButton.styleFrom(
                                                              textStyle: TextStyle(
                                                                fontFamily:
                                                                    'Montserrat',
                                                              ),
                                                              foregroundColor:
                                                                  thm
                                                                      .textcolor,
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                            SizedBox(
                                              width: wid * 0.27,
                                              child: DropdownMenu(
                                                initialSelection:
                                                    (_isSearched)
                                                        ? addcourseid
                                                        : dropdownid[0],
                                                textStyle: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.normal,
                                                  color:
                                                      thm
                                                          .textcolor,
                                                ),
                                                onSelected: (value) {
                                                  setState(() {
                                                    addcourseid = value!;
                                                    electiveSetter();
                                                  });
                                                },
                                                inputDecorationTheme: InputDecorationTheme(
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                menuStyle: MenuStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm
                                                            .backcolor,
                                                      ),
                                                ),

                                                dropdownMenuEntries:
                                                    dropdownid
                                                        .map(
                                                          (
                                                            id,
                                                          ) => DropdownMenuEntry(
                                                            value: id,
                                                            label: id,
                                                            style: MenuItemButton.styleFrom(
                                                              textStyle: TextStyle(
                                                                fontFamily:
                                                                    'Montserrat',
                                                              ),
                                                              foregroundColor:
                                                                  thm
                                                                      .textcolor,
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Spacer(flex: 1),
                                        Theme(
                                          data: Theme.of(context).copyWith(
                                            iconTheme: IconThemeData(
                                              color:
                                                  thm
                                                      .textcolor,
                                            ),
                                          ),
                                          child: Theme(
                                            data: Theme.of(context).copyWith(
                                              inputDecorationTheme: InputDecorationTheme(
                                                labelStyle: TextStyle(
                                                  fontFamily: "Montserrat",
                                                  color:
                                                      thm
                                                          .textcolor,
                                                ),
                                                hintStyle: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  color:
                                                      thm
                                                          .textcolor,
                                                ),
                                                border: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                              ),
                                              textSelectionTheme:
                                                  TextSelectionThemeData(
                                                    cursorColor:
                                                        thm
                                                            .textcolor,
                                                    selectionColor:
                                                        thm
                                                            .textcolor,
                                                    selectionHandleColor:
                                                        thm
                                                            .textcolor,
                                                  ),
                                            ),
                                            child: SizedBox(
                                              width: wid * 0.8,
                                              child: SearchAnchor.bar(
                                                barSide: WidgetStatePropertyAll(
                                                  BorderSide(
                                                    color:
                                                        thm
                                                            .bordcolor,
                                                    width: 1,
                                                  ),
                                                ),
                                                barElevation:
                                                    WidgetStateProperty.all(0),
                                                viewConstraints: BoxConstraints(
                                                  minHeight: 0,
                                                  maxHeight: hei * 0.3,
                                                ),
                                                barTextStyle: WidgetStateProperty.resolveWith((
                                                  states,
                                                ) {
                                                  if (states.contains(
                                                    WidgetState.focused,
                                                  ))
                                                    return TextStyle(
                                                      fontFamily: "Montserrat",
                                                      color:
                                                          thm
                                                              .textcolor,
                                                    );
                                                  return TextStyle(
                                                    fontFamily: "Montserrat",
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  );
                                                }),
                                                barBackgroundColor:

                                                    WidgetStateProperty.all(
                                                      thm
                                                          .backcolor,
                                                    ),
                                                viewBackgroundColor:
                                                (selected_theme=="Black")?
                                                    Color(0xFF3F3C3C):(selected_theme=="Blue")?
                                                Color(0xFF2E2E50):thm.backcolor,
                                                barHintText: 'Search Courses',
                                                barHintStyle: WidgetStateProperty.all(
                                                  TextStyle(
                                                    color:
                                                        thm
                                                            .textcolor,
                                                    fontFamily: 'Montserrat',
                                                  ),
                                                ),
                                                suggestionsBuilder: (
                                                  context,
                                                  controller,
                                                ) {
                                                  final query =
                                                      controller.text
                                                          .toLowerCase();
                                                  final results =
                                                      mcourselist
                                                          .map(
                                                            (course) => course,
                                                          )
                                                          .toList()
                                                          .where(
                                                            (item) => item.title
                                                                .toLowerCase()
                                                                .contains(
                                                                  query,
                                                                ),
                                                          )
                                                          .toList();
                                                  return results.map(
                                                    (item) => ListTile(
                                                      title: Text(
                                                        item.title +
                                                            " (" +
                                                            item.id +
                                                            ")",
                                                        style: TextStyle(
                                                          fontFamily:
                                                              "Montserrat",
                                                          color:
                                                              thm
                                                                  .textcolor,
                                                        ),
                                                      ),
                                                      onTap: () {
                                                        setState(() {
                                                          _isSearched = true;
                                                          addcourse =
                                                              item.id.split(
                                                                " ",
                                                              )[0];
                                                          electiveSetter();
                                                          dropdownid =
                                                              mcourselist
                                                                  .where(
                                                                    (
                                                                      course,
                                                                    ) => course
                                                                        .id
                                                                        .startsWith(
                                                                          addcourse +
                                                                              ' ',
                                                                        ),
                                                                  )
                                                                  .map(
                                                                    (
                                                                      course,
                                                                    ) => course
                                                                        .id
                                                                        .replaceFirst(
                                                                          addcourse +
                                                                              ' ',
                                                                          '',
                                                                        ),
                                                                  )
                                                                  .toList();
                                                          dropdownid.sort(
                                                            (a, b) =>
                                                                a.compareTo(b),
                                                          );
                                                          addcourseid =
                                                              item.id.split(
                                                                " ",
                                                              )[1];
                                                          electiveSetter();
                                                        });
                                                        controller.closeView(
                                                          item.title,
                                                        );
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        Spacer(flex: 1),
                                        Row(
                                          children: [
                                            SizedBox(height: hei * 0.1),
                                            Container(
                                              padding: EdgeInsets.only(
                                                right: 0,
                                              ),
                                              height: hei * 0.08,
                                              width: wid * 0.65,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      thm
                                                          .bordcolor,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),

                                              child: Center(
                                                child: Marquee(
                                                  text: "  $name1  ",
                                                  scrollAxis: Axis.horizontal,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  blankSpace: 10,
                                                  velocity: 30,
                                                  startPadding: 2.0,

                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 21,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                            Container(
                                              height: hei * 0.08,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      thm
                                                          .bordcolor,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "    $credits1    ",
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 22,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                          ],
                                        ),
                                        Spacer(flex: 1),
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: wid * 0.57,
                                              child: Theme(
                                                data: Theme.of(
                                                  context,
                                                ).copyWith(
                                                  inputDecorationTheme:
                                                      InputDecorationTheme(
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets.symmetric(
                                                              vertical: 8,
                                                              horizontal: 8,
                                                            ),
                                                        constraints:
                                                            BoxConstraints.tightFor(
                                                              height:
                                                                  hei * 0.07,
                                                            ),
                                                      ),
                                                ),
                                                child: DropdownMenu(
                                                  textStyle: TextStyle(
                                                    fontSize: 18,
                                                    fontFamily: 'Montserrat',
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                  initialSelection: (selectedelective=="None")?"CDCN":selectedelective,
                                                  inputDecorationTheme: InputDecorationTheme(
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            thm
                                                                .bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            thm
                                                                .bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            thm
                                                                .bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  menuStyle: MenuStyle(
                                                    backgroundColor:
                                                        WidgetStateProperty.all(
                                                          thm
                                                              .backcolor,
                                                        ),
                                                  ),
                                                  dropdownMenuEntries: [
                                                    DropdownMenuEntry(
                                                      value: "CDCN",
                                                      label: "None",
                                                      style: MenuItemButton.styleFrom(
                                                        textStyle: TextStyle(
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                        foregroundColor:
                                                            thm
                                                                .textcolor,
                                                      ),
                                                    ),
                                                    DropdownMenuEntry(
                                                      value: "CDC2",
                                                      label:
                                                          "CDC (" +
                                                          selecteddiscipline
                                                              .substring(2, 4) +
                                                          ")",
                                                      style: MenuItemButton.styleFrom(
                                                        textStyle: TextStyle(
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                        foregroundColor:
                                                            thm
                                                                .textcolor,
                                                      ),
                                                    ),
                                                    DropdownMenuEntry(
                                                      value: "Open Elective",
                                                      label: "Open Elective",
                                                      style: MenuItemButton.styleFrom(
                                                        textStyle: TextStyle(
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                        foregroundColor:
                                                            thm
                                                                .textcolor,
                                                      ),
                                                    ),
                                                    DropdownMenuEntry(
                                                      value:
                                                          "Humanity Elective",
                                                      label:
                                                          "Humanity Elective",
                                                      style: MenuItemButton.styleFrom(
                                                        textStyle: TextStyle(
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                        foregroundColor:
                                                            thm
                                                                .textcolor,
                                                      ),
                                                    ),
                                                    DropdownMenuEntry(
                                                      value:
                                                          "Disciplinary Elective2",
                                                      label:
                                                          "Disciplinary Elective (" +
                                                          selecteddiscipline
                                                              .substring(2, 4) +
                                                          ")",
                                                      style: MenuItemButton.styleFrom(
                                                        textStyle: TextStyle(
                                                          fontFamily:
                                                              'Montserrat',
                                                        ),
                                                        foregroundColor:
                                                            thm
                                                                .textcolor,
                                                      ),
                                                    ),
                                                    if (selecteddiscipline
                                                        .startsWith("B"))
                                                      DropdownMenuEntry(
                                                        value: "CDC1",
                                                        label:
                                                            "CDC (" +
                                                            selecteddiscipline
                                                                .substring(
                                                                  0,
                                                                  2,
                                                                ) +
                                                            ")",
                                                        style: MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm
                                                                  .textcolor,
                                                        ),
                                                      ),
                                                    if (selecteddiscipline
                                                        .startsWith("B"))
                                                      DropdownMenuEntry(
                                                        value:
                                                            "Disciplinary Elective1",
                                                        label:
                                                            "Disciplinary Elective (" +
                                                            selecteddiscipline
                                                                .substring(
                                                                  0,
                                                                  2,
                                                                ) +
                                                            ")",
                                                        style: MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm
                                                                  .textcolor,
                                                        ),
                                                      ),
                                                  ],
                                                  onSelected: (value) {
                                                    selectedelective = value!;
                                                  },
                                                ),
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                            SizedBox(
                                              width: wid * 0.26,
                                              child: Theme(
                                                data: Theme.of(
                                                  context,
                                                ).copyWith(
                                                  inputDecorationTheme:
                                                      InputDecorationTheme(
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets.symmetric(
                                                              vertical: 8,
                                                              horizontal: 8,
                                                            ),
                                                        constraints:
                                                            BoxConstraints.tightFor(
                                                              height:
                                                                  hei * 0.07,
                                                            ),
                                                      ),
                                                ),
                                                child: DropdownMenu(
                                                  textStyle: TextStyle(
                                                    fontSize: 20,
                                                    fontFamily: 'Montserrat',
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color:
                                                        thm
                                                            .textcolor,
                                                  ),
                                                  initialSelection: "A",
                                                  inputDecorationTheme: InputDecorationTheme(
                                                    enabledBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            thm
                                                                .bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            thm
                                                                .bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color:
                                                            thm
                                                                .bordcolor,
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  menuStyle: MenuStyle(
                                                    backgroundColor:
                                                        WidgetStateProperty.all(
                                                          thm
                                                              .backcolor,
                                                        ),
                                                  ),
                                                  dropdownMenuEntries:
                                                    grades.map((id)=> DropdownMenuEntry(value: id, label: id, style: MenuItemButton.styleFrom(
                                                      textStyle: TextStyle(
                                                        fontFamily:
                                                        'Montserrat',
                                                      ),
                                                      foregroundColor:
                                                      thm
                                                          .textcolor,
                                                    ),
                                                    )).toList()
                                                  ,
                                                  onSelected: (value) {
                                                    selectedgrade =
                                                        reversegradecalc(value!);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Spacer(flex: 1),
                                        Row(
                                          children: [
                                            Spacer(flex: 1),
                                            SizedBox(
                                              height: hei * 0.08,
                                              width: wid * 0.8,
                                              child: FloatingActionButton(
                                                backgroundColor:
                                                    thm
                                                        .butcolor,
                                                child: Text(
                                                  "Add Course",
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontSize: 22,
                                                    color:
                                                        thm
                                                            .highcolor,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  _isSearched = false;
                                                  setState(() {
                                                    if (sitems.any(
                                                      (course) =>
                                                          course.id ==
                                                          "$addcourse $addcourseid",
                                                    )) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  "Montserrat",
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                              fontSize: 16,
                                                            ),
                                                            "This course already exists",
                                                          ),
                                                          duration: Duration(
                                                            seconds: 3,
                                                          ),
                                                        ),
                                                      );
                                                    } else {
                                                      Mastercourselist?
                                                      tempcourse = mcourselist
                                                          .lastWhere(
                                                            (course) =>
                                                                course.id ==
                                                                "$addcourse $addcourseid",
                                                          );
                                                      if (selectedprofile ==
                                                          1) {
                                                        addOrUpdateCourse(
                                                          Course(
                                                            elective:
                                                                selectedelective,
                                                            title:
                                                                tempcourse
                                                                    .title,
                                                            sem: currentsem,
                                                            id:
                                                                "$addcourse $addcourseid",
                                                            discipline:
                                                                ((selecteddiscipline
                                                                            .substring(
                                                                              0,
                                                                              2,
                                                                            ) !=
                                                                        "--")
                                                                    ? selecteddiscipline
                                                                        .substring(
                                                                          0,
                                                                          2,
                                                                        )
                                                                    : selecteddiscipline
                                                                        .substring(
                                                                          2,
                                                                          4,
                                                                        )),
                                                            grade1:
                                                                selectedgrade,
                                                            grade2: -2,
                                                            credits:
                                                                tempcourse
                                                                    .credits,
                                                          ),
                                                        );
                                                        selectedelective = "None";
                                                      } else if (selectedprofile ==
                                                          2) {
                                                        addOrUpdateCourse(
                                                          Course(
                                                            elective:
                                                                selectedelective,
                                                            title:
                                                                tempcourse
                                                                    .title,
                                                            sem: currentsem,
                                                            id:
                                                                "$addcourse $addcourseid",
                                                            discipline:
                                                                ((selecteddiscipline
                                                                            .substring(
                                                                              0,
                                                                              2,
                                                                            ) !=
                                                                        "--")
                                                                    ? selecteddiscipline
                                                                        .substring(
                                                                          0,
                                                                          2,
                                                                        )
                                                                    : selecteddiscipline
                                                                        .substring(
                                                                          2,
                                                                          4,
                                                                        )),
                                                            grade1: -2,
                                                            grade2:
                                                                selectedgrade,
                                                            credits:
                                                                tempcourse
                                                                    .credits,
                                                          ),
                                                        );
                                                        selectedelective = "None";
                                                      }

                                                      selectedgrade = 10;
                                                      currentsem = currentsem;
                                                      selecteddiscipline =
                                                          selecteddiscipline;
                                                      batch=batch;
                                                      addcourse = "AN";
                                                      addcourseid = "F311";
                                                      electiveSetter();
                                                      dropdownid =
                                                          mcourselist
                                                              .where(
                                                                (
                                                                  course,
                                                                ) => course.id
                                                                    .startsWith(
                                                                      "AN" +
                                                                          ' ',
                                                                    ),
                                                              )
                                                              .map(
                                                                (
                                                                  course,
                                                                ) => course.id
                                                                    .replaceFirst(
                                                                      "AN" +
                                                                          ' ',
                                                                      '',
                                                                    ),
                                                              )
                                                              .toList();
                                                      dropdownid.sort(
                                                        (a, b) =>
                                                            a.compareTo(b),
                                                      );
                                                      sort(sitems);
                                                      _isCardOpen = false;
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : SizedBox.shrink(),
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child:
                  !degree_selected
                      ? Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: !degree_selected ? 0.6 : 0.0,
                            duration: Duration(milliseconds: 500),
                            child: GestureDetector(
                              onTap: () async {},
                              child: Container(
                                color:
                                    thm.textcolor,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          Center(
                            child: AnimatedScale(
                              scale: !degree_selected ? 1.0 : 0.8,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              child: Card(
                                elevation: 40,
                                margin: EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color:
                                        thm.textcolor,
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    height: hei * 0.42,
                                    width: wid * 0.75,
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                "Select your discipline",
                                                softWrap: true,
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 22,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Spacer(flex: 2),
                                        Row(
                                          children: [
                                            Text(
                                              "Dual",
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 18,
                                                fontWeight: FontWeight.normal,
                                                color:
                                                    thm
                                                        .textcolor,
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                            Theme(
                                              data: Theme.of(context).copyWith(
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 8,
                                                            horizontal: 8,
                                                          ),
                                                      constraints:
                                                          BoxConstraints.tightFor(
                                                            height: hei * 0.07,
                                                          ),
                                                    ),
                                              ),
                                              child: DropdownMenu(
                                                inputDecorationTheme: InputDecorationTheme(
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                textStyle: TextStyle(
                                                  fontSize: 16,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  color:
                                                      thm
                                                          .textcolor,
                                                ),
                                                initialSelection: "",
                                                menuStyle: MenuStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm
                                                            .backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries: degreelist.where((id)=> id.startsWith("B")).map((id) => DropdownMenuEntry(value: id, label: id,style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),)).toList() + [DropdownMenuEntry(value: "B-", label: "Other",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),),DropdownMenuEntry(value: "--", label: "None",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),)],
                                                onSelected: (value) {
                                                  selectdual = value!;
                                                  selecteddiscipline =
                                                      value + selecengg;
                                                  _isDisciplineChanged = true;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        Spacer(flex: 1),
                                        Row(
                                          children: [
                                            Text(
                                              "Discipline",
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 18,
                                                fontWeight: FontWeight.normal,
                                                color:
                                                    thm
                                                        .textcolor,
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                            Theme(
                                              data: Theme.of(context).copyWith(
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            vertical: 8,
                                                            horizontal: 8,
                                                          ),
                                                      constraints:
                                                          BoxConstraints.tightFor(
                                                            height: hei * 0.07,
                                                          ),
                                                    ),
                                              ),
                                              child: DropdownMenu(
                                                textStyle: TextStyle(
                                                  fontSize: 16,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  color:
                                                      thm
                                                          .textcolor,
                                                ),
                                                initialSelection: "",
                                                inputDecorationTheme: InputDecorationTheme(
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          thm
                                                              .bordcolor,
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                                menuStyle: MenuStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm
                                                            .backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries: degreelist.where((id)=> id.startsWith("A")).map((id) => DropdownMenuEntry(value: id, label: id,style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),)).toList() + [DropdownMenuEntry(value: "--", label: "Other",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .textcolor, ),)],
                                                onSelected: (value) {
                                                  selecengg = value!;
                                                  selecteddiscipline =
                                                      selectdual + value;
                                                  _isDisciplineChanged = true;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        Spacer(flex: 1),
                                        // Row(
                                        //   children: [
                                        //     Text(
                                        //       "Campus",
                                        //       style: TextStyle(
                                        //         fontSize: 18,
                                        //         color: thm.textcolor,
                                        //         fontFamily: 'Montserrat',
                                        //         fontWeight: FontWeight.normal,
                                        //       ),
                                        //     ),
                                        //     Spacer(flex: 1,),
                                        //     DropdownMenu(
                                        //       initialSelection: selectedcampus,
                                        //       onSelected: (String? value) {
                                        //         setState(() {
                                        //           if(selectedcampus!=value!){
                                        //             erase=1;
                                        //           }
                                        //           selectedcampus = value;
                                        //           setdis();
                                        //         });
                                        //       },
                                        //       textAlign: TextAlign.center,
                                        //       textStyle: TextStyle(
                                        //         fontFamily: 'Montserrat',
                                        //         color: thm.highcolor,
                                        //         fontSize: 18,
                                        //         fontWeight: FontWeight.bold,
                                        //       ),
                                        //       inputDecorationTheme: InputDecorationTheme(
                                        //         enabledBorder: OutlineInputBorder(
                                        //           borderSide: BorderSide(
                                        //             color:
                                        //             thm
                                        //                 .sepcolor, // Set border color to white
                                        //             width: 1.5,
                                        //           ),
                                        //         ),
                                        //         focusedBorder: OutlineInputBorder(
                                        //           borderSide: BorderSide(
                                        //             color:
                                        //             thm
                                        //                 .sepcolor, // Set border color to white when focused
                                        //             width: 1.5,
                                        //           ),
                                        //         ),
                                        //         border: OutlineInputBorder(
                                        //           borderSide: BorderSide(
                                        //             color:
                                        //             thm
                                        //                 .sepcolor, // Default border color
                                        //             width: 1.5,
                                        //           ),
                                        //         ),
                                        //       ),
                                        //       menuStyle: MenuStyle(
                                        //         backgroundColor: WidgetStateProperty.all(
                                        //           thm.backcolor,
                                        //         ),
                                        //       ),
                                        //       dropdownMenuEntries: campuslist.map((id) => DropdownMenuEntry(value: id, label: id,style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .highcolor, ),)).toList(),
                                        //     ),
                                        //     SizedBox(height: 10),
                                        //
                                        //   ],
                                        // ),
                                        // Spacer(flex: 1,),
                                        Row(children: [
                                          Text("Batch",style: TextStyle(fontFamily: "Montserrat",fontSize: 18,color: thm.textcolor),),
                                          Spacer(flex: 1,),
                                          SizedBox(width: 30,child: TextField(keyboardType: TextInputType.number,inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],controller: _batchController1,
                                              onSubmitted: (value){
                                                if (_batchController1.text.isNotEmpty) {
                                                  batch = int.parse(value);
                                                }
                                                setdis();
                                              },
                                              onChanged: (value){
                                                if (_batchController1.text.isNotEmpty) {
                                                  batch = int.parse(value);
                                                }
                                                setdis();
                                              }
                                              )
                                          ),],),
                                        SizedBox(height: 5,),
                                        Row(
                                          children: [
                                            Spacer(flex: 1),
                                            SizedBox(
                                              height: hei * 0.08,
                                              width: wid * 0.7,
                                              child: FloatingActionButton(
                                                child: Text(
                                                  "Done",
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontSize: 22,
                                                  ),
                                                ),
                                                onPressed: () async {
                                                  if (_isDisciplineChanged) {
                                                    selecteddiscipline =
                                                        selecteddiscipline;
                                                    batch= batch;
                                                    await setdis();
                                                    await initializeCourses();
                                                    await Future.delayed(
                                                      Duration(
                                                        milliseconds: 100,
                                                      ),
                                                    );
                                                    sort(sitems);
                                                    setState(() {
                                                      selectedgrade = 10;
                                                      currentsem = currentsem;
                                                      selecteddiscipline =
                                                          selecteddiscipline;
                                                      batch=batch;
                                                      addcourse = "AN";
                                                      addcourseid = "F311";
                                                      electiveSetter();
                                                      dropdownid =
                                                          mcourselist
                                                              .where(
                                                                (
                                                                  course,
                                                                ) => course.id
                                                                    .startsWith(
                                                                      "AN" +
                                                                          ' ',
                                                                    ),
                                                              )
                                                              .map(
                                                                (
                                                                  course,
                                                                ) => course.id
                                                                    .replaceFirst(
                                                                      "AN" +
                                                                          ' ',
                                                                      '',
                                                                    ),
                                                              )
                                                              .toList();
                                                      dropdownid.sort(
                                                        (a, b) =>
                                                            a.compareTo(b),
                                                      );
                                                      sort(sitems);
                                                      degree_selected = true;
                                                    });
                                                    _isDisciplineChanged =
                                                        false;
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          style: TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontSize: 16,
                                                          ),
                                                          "Select Discipline",
                                                        ),
                                                        duration: Duration(
                                                          seconds: 3,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : SizedBox.shrink(),
            ),
          ],
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.grey.withValues(alpha: 0.05),
            highlightColor: Colors.grey.withValues(alpha: 0.05),
            hoverColor: Colors.grey.withValues(alpha: 0.05),
          ),
          child: BottomNavigationBar(
            backgroundColor:
                thm.backcolor,
            selectedItemColor:
                thm.highcolor,
            unselectedItemColor:
               thm.unscolor,
            currentIndex: selectedprofile - 1,
            onTap: (index) {
              setState(() {
                if (index + 1 > selectedprofile) {
                  _isrightswipe = true;
                } else {
                  _isrightswipe = false;
                }
                selectedprofile = index + 1;
              });
            },

            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.account_box_outlined),
                label: profile1n,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_box_outlined),
                label: profile2n,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.comment_bank_outlined),
                label: "Compare",
              ),
            ],
            selectedLabelStyle: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.normal,
              fontSize: 8,
            ),
          ),
        ),
      ),
    );
  }
}
