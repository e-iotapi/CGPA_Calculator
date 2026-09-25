import 'dart:async';
import 'dart:js_interop';
import 'package:cgpa_calculator/auth_util.dart';
import 'package:cgpa_calculator/constants.dart';
import 'package:cgpa_calculator/sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web/web.dart' as web;
import 'package:cgpa_calculator/script.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

String selectdual = selecteddiscipline.substring(0, 2);
String selecengg = selecteddiscipline.substring(2, 4);

class _SettingsState extends State<Settings> {
  Future<void> _signOut() async {
    await Sync.stop();
    await FirebaseAuth.instance.signOut();
    await Sync.clearLocal();
    web.window.location.reload();
  }

  /// Opens a native file picker and returns the chosen file's text, or null
  /// if the user cancelled.
  Future<String?> _pickJsonText() {
    final input =
        web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = '.json,application/json';
    final done = Completer<String?>();

    input.onchange =
        ((web.Event _) {
          final files = input.files;
          if (files == null || files.length == 0) {
            if (!done.isCompleted) done.complete(null);
            return;
          }
          final reader = web.FileReader();
          reader.onload =
              ((web.Event _) {
                if (done.isCompleted) return;
                final r = reader.result;
                done.complete(r.isA<JSString>() ? (r as JSString).toDart : null);
              }).toJS;
          reader.onerror =
              ((web.Event _) {
                if (!done.isCompleted) {
                  done.completeError('Could not read the file');
                }
              }).toJS;
          reader.readAsText(files.item(0)!);
        }).toJS;

    // Fires when the picker is dismissed without choosing anything.
    input.addEventListener(
      'cancel',
      ((web.Event _) {
        if (!done.isCompleted) done.complete(null);
      }).toJS,
    );

    input.click();
    return done.future;
  }

  Future<void> _submitReport() async {
    final controller = TextEditingController();
    String type = 'Bug';
    const types = ['Bug', 'Missing course', 'Suggestion'];

    final send = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheet) => AlertDialog(
                  backgroundColor: thm.backcolor,
                  title: Text(
                    'Report a problem',
                    style: TextStyle(
                      color: thm.textcolor,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final t in types)
                              GestureDetector(
                                onTap: () => setSheet(() => type = t),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color:
                                        type == t
                                            ? thm.highcolor.withValues(
                                              alpha: 0.15,
                                            )
                                            : null,
                                    border: Border.all(
                                      color:
                                          type == t
                                              ? thm.highcolor
                                              : thm.bordcolor,
                                    ),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 12,
                                      color:
                                          type == t
                                              ? thm.highcolor
                                              : thm.textcolor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 14),
                        TextField(
                          controller: controller,
                          maxLines: 5,
                          maxLength: 2000,
                          style: TextStyle(
                            color: thm.textcolor,
                            fontSize: 13,
                            fontFamily: 'Montserrat',
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'What went wrong, or which course is missing?',
                            hintStyle: TextStyle(
                              color: thm.textcolor.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontFamily: 'Montserrat',
                            ),
                            counterStyle: TextStyle(
                              color: thm.textcolor.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: thm.bordcolor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: thm.highcolor),
                            ),
                          ),
                        ),
                        Text(
                          'Sent with your email so a reply is possible.',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Montserrat',
                            color: thm.textcolor.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: thm.textcolor),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Send',
                        style: TextStyle(color: thm.highcolor),
                      ),
                    ),
                  ],
                ),
          ),
    );
    if (send != true) return;

    final message = controller.text.trim();
    if (message.isEmpty) {
      _toast('Nothing to send — the message was empty.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('You need to be signed in to send a report.');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'uid': user.uid,
        'email': user.email ?? '',
        'type': type,
        'message': message,
        'discipline': selecteddiscipline,
        'campus': selectedcampus,
        'batch': batch,
        'appVersion': '2.3.1+131',
        'userAgent': web.window.navigator.userAgent,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _toast('Thanks — your report was sent.');
    } catch (e) {
      _toast('Could not send the report: $e');
    }
  }

  void _exportCsv() {
    try {
      final name = exportGradesCsv();
      _toast('Downloaded $name');
    } catch (e) {
      _toast('Export failed: $e');
    }
  }

  Future<void> _importFromFile() async {
    String? text;
    try {
      text = await _pickJsonText();
    } catch (e) {
      _toast('Could not read the file: $e');
      return;
    }
    if (text == null) return; // cancelled

    Map<String, int> counts;
    try {
      counts = Sync.validate(text);
    } catch (e) {
      _toast(
        e is FormatException ? "That file isn't a grade backup: ${e.message}" : '$e',
      );
      return;
    }

    final summary = [
      if (counts['coursesBox'] != null) '${counts['coursesBox']} courses',
      if (counts['settingsBox'] != null) '${counts['settingsBox']} settings',
      if ((counts['offshootBox'] ?? 0) > 0)
        '${counts['offshootBox']} offshoot courses',
    ].join(', ');

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: thm.backcolor,
            title: Text(
              'Replace your grades?',
              style: TextStyle(color: thm.textcolor, fontFamily: 'Montserrat'),
            ),
            content: Text(
              'This file contains $summary.\n\n'
              'Importing replaces everything currently saved to your account. '
              'This cannot be undone.',
              style: TextStyle(
                color: thm.textcolor,
                fontSize: 14,
                fontFamily: 'Montserrat',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: TextStyle(color: thm.textcolor)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Import', style: TextStyle(color: thm.highcolor)),
              ),
            ],
          ),
    );
    if (ok != true) return;

    try {
      await Sync.apply(text);
      await Sync.push();
      web.window.location.reload();
    } catch (e) {
      _toast('Import failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: thm.cardcolor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: thm.bordcolor, width: 1),
        ),
        content: Text(
          msg,
          style: TextStyle(
            color: thm.textcolor,
            fontFamily: 'Montserrat',
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _importFromOldSite() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: thm.backcolor,
            title: Text(
              'Import from old site',
              style: TextStyle(color: thm.textcolor, fontFamily: 'Montserrat'),
            ),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: controller,
                maxLines: 8,
                style: TextStyle(
                  color: thm.textcolor,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                ),
                decoration: InputDecoration(
                  hintText: 'Paste the JSON copied from the old site',
                  hintStyle: TextStyle(
                    color: thm.textcolor.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: thm.bordcolor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: thm.highcolor),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: TextStyle(color: thm.textcolor)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Import', style: TextStyle(color: thm.highcolor)),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await Sync.apply(controller.text);
      await Sync.push();
      web.window.location.reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: thm.cardcolor,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Import failed: $e',
            style: TextStyle(color: thm.textcolor, fontFamily: 'Montserrat'),
          ),
        ),
      );
    }
  }

  final TextEditingController myController1 = TextEditingController(
    text: profile1n,
  );
  final TextEditingController myController2 = TextEditingController(
    text: profile2n,
  );
  bool _isProfileCardOpen = false;
  TextEditingController _batchController = TextEditingController(text: batch.toString());
  @override
  Widget build(BuildContext context) {
    var thm = themes.firstWhere((theme) => theme.theme == selected_theme);
    setnavcolor();
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: thm.textcolor),
        title: Text(
          "Hi, ${firstNameOf(FirebaseAuth.instance.currentUser)}",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 20,
            color: thm.textcolor,
          ),
        ),
        backgroundColor: thm.backcolor,
        actions: [
          Transform.scale(scale: 1.2,child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: thm.backcolor,
        shape: CircleBorder()
            )
            ,
            child: Icon(Icons.info_outline_rounded,color: thm.iconcolor,),
          onPressed: ()=> showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: thm.backcolor,
                title: Text('Updates',style: TextStyle(fontFamily: 'Montserrat',color: thm.highcolor),textAlign: TextAlign.center,),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                [Text('1) Click on Reset to update courses',textAlign: TextAlign.center,style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),
                  Text('2) Play Store Updates will show up as Prompts',textAlign: TextAlign.center,style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),
                  Text('3) Bugs / New course requests can be sent from the app itself',textAlign: TextAlign.center,style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),
                  Text('4) Updated BITS K101 and BITS F101 to 0.5 credits. Delete and add these courses or use reset to update.',textAlign: TextAlign.center,style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),
                  Text('5) Offshoot is now its own tab at the bottom, next to Compare.',textAlign: TextAlign.center,style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),
                  Text('6) Hold on grade to change quickly.',textAlign: TextAlign.center,style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),
                  Text('7) Reload and hold the page to clear grades.',textAlign: TextAlign.center,style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),

                ],),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close',style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor),),
                  ),
                ],
              );
            },
          ),),),
        ]
      ),
      backgroundColor: thm.backcolor, //themes[0].backcolor,
      body: SafeArea(child: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 15),
              Text(
                "Changing First Discipline Will Delete Grades",
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: thm.textcolor,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.normal,
                ),
              ),
              SizedBox(height: 15),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: Row(
                  children: [
                    Column(
                      children: [
                        DropdownMenu(
                          initialSelection:
                              (selecteddiscipline.length == 4)
                                  ? selecteddiscipline.substring(0, 2)
                                  : (selecteddiscipline.length == 2 &&
                                      selecteddiscipline.substring(0, 1) == 'B')
                                  ? selecteddiscipline.substring(0, 2)
                                  : "None",
                          onSelected: (String? value) {
                            setState(() {
                              selectdual = value!;
                              if (selecteddiscipline.substring(0, 2) != selectdual) {
                                erase = 1;
                              }
                              selecteddiscipline = value + selecengg;
                            });
                          },
                          textAlign: TextAlign.center,
                          textStyle: TextStyle(
                            color: thm.highcolor,
                            fontSize: 18,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    thm
                                        .sepcolor, // Set border color to white
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    thm
                                        .sepcolor, // Set border color to white when focused
                                width: 1.5,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    thm
                                        .sepcolor, // Default border color
                                width: 1.5,
                              ),
                            ),
                          ),
                          menuStyle: MenuStyle(
                            backgroundColor: WidgetStateProperty.all(
                              thm.backcolor,
                            ),
                          ),
                          dropdownMenuEntries: degreelist.where((id)=> id.startsWith("B")).map((id) => DropdownMenuEntry(value: id, label: id,style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .highcolor, ),)).toList() + [DropdownMenuEntry(value: "B-", label: "Other",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .highcolor, ),),DropdownMenuEntry(value: "--", label: "None",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .highcolor, ),)],
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Dual Discipline",
                          style: TextStyle(
                            color: thm.textcolor,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    Spacer(flex: 1),
                    Column(
                      children: [
                        DropdownMenu(
                          initialSelection:
                              (selecteddiscipline.length == 4)
                                  ? selecteddiscipline.substring(2, 4)
                                  : (selecteddiscipline.length == 2 &&
                                      selecteddiscipline.substring(0, 1) == 'A')
                                  ? selecteddiscipline.substring(0, 2)
                                  : "Other",
                          onSelected: (String? value) {
                            setState(() {
                              selecengg = value!;
                              if (selecteddiscipline.substring(2, 4) !=
                                  selecengg) {
                                if (erase != 1 && selecteddiscipline.startsWith("B")) {
                                  erase = 2;
                                }
                                else{
                                  erase=1;
                                }
                              }
                              selecteddiscipline = selectdual + value;
                            });
                          },
                          textAlign: TextAlign.center,
                          textStyle: TextStyle(
                            fontFamily: 'Montserrat',
                            color: thm.highcolor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    thm
                                        .sepcolor, // Set border color to white
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    thm
                                        .sepcolor, // Set border color to white when focused
                                width: 1.5,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    thm
                                        .sepcolor, // Default border color
                                width: 1.5,
                              ),
                            ),
                          ),
                          menuStyle: MenuStyle(
                            backgroundColor: WidgetStateProperty.all(
                              thm.backcolor,
                            ),
                          ),
                          dropdownMenuEntries: degreelist.where((id)=> id.startsWith("A")).map((id) => DropdownMenuEntry(value: id, label: id,style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .highcolor, ),)).toList() + [DropdownMenuEntry(value: "--", label: "Other",style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .highcolor, ),)],
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Discipline",
                          style: TextStyle(
                            color: thm.textcolor,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    //Remove following comment for campus
                    //Spacer(flex: 1),
                    // Column(
                    //   children: [
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
                    //     Text(
                    //       "Campus",
                    //       style: TextStyle(
                    //         color: thm.textcolor,
                    //         fontFamily: 'Montserrat',
                    //         fontWeight: FontWeight.bold,
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),

              Column(
                children: [
                  Row(children: [
                SizedBox(width: 25,),
                Text("Batch",style: TextStyle(fontFamily: "Montserrat",fontSize: 16,color: thm.textcolor),),
                SizedBox(width: 10,),
                SizedBox(width: 25,child: TextField(keyboardType: TextInputType.number,style: TextStyle(fontFamily: "Montserrat",fontSize: 16,color: thm.textcolor),inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],controller: _batchController,
                    onChanged: (value){
                      if (_batchController.text.isNotEmpty) {
                        if(batch<25 && int.parse(value)>=25){
                          erase=1;
                        }
                        else if(batch>=25 && int.parse(value)<25){
                          erase =1;
                        }
                        batch = int.parse(value);
                      }
                      setdis();
                      initializeCourses();
                    }),
                ),
                Spacer(flex: 1,),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.05,
                      width: 100,
                      child: FloatingActionButton(
                        heroTag: 'settings_reset_btn',
                        key: ValueKey("Reset"),
                        elevation: 1,
                        focusElevation: 0,
                        hoverElevation: 0,
                        highlightElevation: 0,
                        disabledElevation: 0,
                        backgroundColor: thm.cardcolor,
                        child: Text(
                          "Reset",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 18,
                            color: thm.highcolor,
                          ),
                        ),
                        onPressed: ()=> showDialog(
                              context: context,
                              builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: thm.backcolor,
                              title: Text('Reset?',style: TextStyle(fontFamily: 'Montserrat',color: thm.highcolor),textAlign: TextAlign.center,),
                              content: Text('Resetting Courses will Delete grade data',style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor)),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>Navigator.pop(context),
                                  child: Text('Cancel',style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor),),
                                ),TextButton(
                              onPressed: () async
                              {
                                erase = 1;
                                await initializeCourses();
                                Navigator.pop(context);
                              },
                              child: Text('Reset',style: TextStyle(fontFamily: 'Montserrat',color: thm.textcolor),),
                              ),
                              ],
                              );
                        }
                      ),
                    ),),
                    SizedBox(width: 25,)
                  ],),
                ],),
              SizedBox(height: 25),
              Container(
                height: 0.5,
                width: MediaQuery.of(context).size.width * 0.8,
                color: thm.sepcolor,
              ),
              SizedBox(height: 25),
              Padding(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  children: [
                    Text(
                      "Theme",
                      style: TextStyle(
                        color:
                            thm
                                .textcolor,
                        fontSize: 20,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(flex: 1),
                    DropdownMenu(
                      initialSelection: selected_theme,
                      onSelected: (String? value) async {
                        selected_theme = value!;
                        thm = themes.firstWhere((theme) => theme.theme == selected_theme);
                        await settheme();
                        setState(() {
                          selected_theme = value;
                          setnavcolor();
                          thm = themes.firstWhere((theme) => theme.theme == selected_theme);
                        });
                      },
                      textAlign: TextAlign.center,
                      textStyle: TextStyle(
                        color:
                            thm
                                .highcolor,
                        fontSize: 17,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                      inputDecorationTheme: InputDecorationTheme(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: thm.sepcolor, // Set border color to white
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                thm.sepcolor, // Set border color to white when focused
                            width: 1.5,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: thm.sepcolor, // Default border color
                            width: 1.5,
                          ),
                        ),
                      ),
                      menuStyle: MenuStyle(
                        backgroundColor: WidgetStateProperty.all(thm.backcolor),
                      ),
                      dropdownMenuEntries: themes.map((id) => DropdownMenuEntry(value: id.theme, label: id.theme,style: MenuItemButton.styleFrom( textStyle: TextStyle( fontFamily: 'Montserrat', ), foregroundColor: thm .highcolor, ),)).toList(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.05,
                    width: MediaQuery.of(context).size.width * 0.90,
                    child: FloatingActionButton(
                      heroTag: 'settings_profile_btn',
                      key: ValueKey("profile"),
                      elevation: 1,
                      focusElevation: 0,
                      hoverElevation: 0,
                      highlightElevation: 0,
                      disabledElevation: 0,
                      backgroundColor: thm.cardcolor,
                      child: Text(
                        "Set Profile",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 18,
                          color: thm.highcolor,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isProfileCardOpen = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 25),
              Container(
                height: 0.5,
                width: MediaQuery.of(context).size.width * 0.8,
                color: thm.sepcolor,
              ),
              SizedBox(height: 25),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.05,
                width: MediaQuery.of(context).size.width * 0.90,
                child: FloatingActionButton(
                  heroTag: 'settings_report_btn',
                  key: ValueKey("report"),
                  elevation: 1,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  disabledElevation: 0,
                  backgroundColor: thm.cardcolor,
                  child: Text(
                    "Report a Bug or Add courses",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 18,
                      color: thm.highcolor,
                    ),
                  ),
                    onPressed: _submitReport,
                ),
              ),

              SizedBox(height: 14),
              Text(
                FirebaseAuth.instance.currentUser?.email ?? "Not signed in",
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                  color: thm.textcolor.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.05,
                width: MediaQuery.of(context).size.width * 0.90,
                child: FloatingActionButton(
                  heroTag: 'settings_export_csv_btn',
                  key: ValueKey("exportcsv"),
                  elevation: 1,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  disabledElevation: 0,
                  backgroundColor: thm.cardcolor,
                  onPressed: _exportCsv,
                  child: Text(
                    "Export grades (.csv)",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 18,
                      color: thm.highcolor,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.05,
                width: MediaQuery.of(context).size.width * 0.90,
                child: FloatingActionButton(
                  heroTag: 'settings_import_file_btn',
                  key: ValueKey("importfile"),
                  elevation: 1,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  disabledElevation: 0,
                  backgroundColor: thm.cardcolor,
                  onPressed: _importFromFile,
                  child: Text(
                    "Import backup file (.json)",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 18,
                      color: thm.highcolor,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.05,
                width: MediaQuery.of(context).size.width * 0.90,
                child: FloatingActionButton(
                  heroTag: 'settings_import_btn',
                  key: ValueKey("import"),
                  elevation: 1,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  disabledElevation: 0,
                  backgroundColor: thm.cardcolor,
                  onPressed: _importFromOldSite,
                  child: Text(
                    "Import from old site",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 18,
                      color: thm.highcolor,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.05,
                width: MediaQuery.of(context).size.width * 0.90,
                child: FloatingActionButton(
                  heroTag: 'settings_signout_btn',
                  key: ValueKey("signout"),
                  elevation: 1,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  disabledElevation: 0,
                  backgroundColor: thm.cardcolor,
                  onPressed: _signOut,
                  child: Text(
                    "Sign out",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 18,
                      color: thm.highcolor,
                    ),
                  ),
                ),
              ),

              Spacer(flex: 1),
        SizedBox(height: 10),
              Text(
                "Made by Siddharth Mishra",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                  color: thm.textcolor,
                ),
              ),
              GestureDetector(
                onTap:
                    () => launchUrl(
                      Uri.parse('mailto:siddhu.cms@gmail.com'),
                    ),
                child: Text(
                  "siddhu.cms@gmail.com",
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Montserrat',
                    color: thm.textcolor,
                  ),
                ),
              ),
              SizedBox(height: 4),
              GestureDetector(
                onTap:
                    () => launchUrl(
                      Uri.parse('https://github.com/e-iotapi'),
                      mode: LaunchMode.externalApplication,
                    ),
                child: Text(
                  "github.com/e-iotapi",
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Montserrat',
                    decoration: TextDecoration.underline,
                    decorationColor: thm.highcolor,
                    color: thm.highcolor,
                  ),
                ),
              ),
              SizedBox(height: 6),
              GestureDetector(
                onTap:
                    () => launchUrl(
                      Uri.parse(
                        'https://github.com/Srijen-Raja/CGPA_Calculator',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                child: Text(
                  "Based on the CGPA Calculator by Srijen Raja \u00b7 Apache-2.0",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'Montserrat',
                    color: thm.textcolor.withValues(alpha: 0.55),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 5),
            ],
          ),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child:
                _isProfileCardOpen
                    ? Stack(
                      children: [
                        AnimatedOpacity(
                          opacity: _isProfileCardOpen ? 0.6 : 0.0,
                          duration: Duration(milliseconds: 500),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isProfileCardOpen = false;
                              });
                            },
                            child: Container(
                              color: thm.backcolor,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        Center(
                          child: AnimatedScale(
                            scale: _isProfileCardOpen ? 1.0 : 0.8,
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            child: Card(
                              color: thm.backcolor,
                              elevation: 40,
                              margin: EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: thm.textcolor,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.44,
                                  width:
                                      MediaQuery.of(context).size.width * 0.85,
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Enter name for Profile 1",
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.normal,
                                              color: thm.textcolor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(flex: 1),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.50,
                                            child: TextField(
                                              controller: myController1,
                                              decoration: InputDecoration(
                                                helperText:
                                                    'Enter less than 9 letters',
                                              ),
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                color:
                                                    thm
                                                        .textcolor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(flex: 3),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Enter name for Profile 2",
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.normal,
                                              color: thm.textcolor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(flex: 1),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.50,
                                            child: TextField(
                                              controller: myController2,
                                              decoration: InputDecoration(
                                                helperText:
                                                    'Enter less than 9 letters',
                                              ),
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                color:
                                                    thm
                                                        .textcolor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(flex: 2),
                                      Row(
                                        children: [
                                          Spacer(flex: 1),
                                          SizedBox(
                                            height:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height *
                                                0.08,
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.8,
                                            child: FloatingActionButton(
                                              heroTag: 'settings_update_profile_btn',
                                              backgroundColor: thm.butcolor,
                                              child: Text(
                                                "Update Profile",
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  fontSize: 22,
                                                  color:
                                                      thm
                                                          .highcolor,
                                                ),
                                              ),
                                              onPressed: () async{
                                                setState(() {
                                                  profile1n =
                                                      (myController1
                                                                      .text
                                                                      .length >
                                                                  0 &&
                                                              myController1
                                                                      .text
                                                                      .length <=
                                                                  9)
                                                          ? myController1.text
                                                          : (myController1
                                                                  .text
                                                                  .length ==
                                                              0)
                                                          ? "Profile 1"
                                                          : (myController1
                                                                  .text
                                                                  .length >
                                                              9)
                                                          ? myController1.text
                                                              .substring(0, 9)
                                                          : "-";
                                                  profile2n =
                                                      (myController2
                                                                      .text
                                                                      .length >
                                                                  0 &&
                                                              myController2
                                                                      .text
                                                                      .length <=
                                                                  9)
                                                          ? myController2.text
                                                          : (myController2
                                                                  .text
                                                                  .length ==
                                                              0)
                                                          ? "Profile 2"
                                                          : (myController2
                                                                  .text
                                                                  .length >
                                                              9)
                                                          ? myController2.text
                                                              .substring(0, 9)
                                                          : "-";
                                                  _isProfileCardOpen = false;
                                                });
                                                await setprof();
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
      )),
    );
  }
}
