import 'dart:math';

import 'package:cgpa_calculator/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

String selectdual = selecteddiscipline.substring(0, 2);
String selecengg = selecteddiscipline.substring(2, 4);

class _SettingsState extends State<Settings> {
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
          "Settings",
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
      body: Stack(
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
                                if (erase != 1) {
                                  erase = 2;
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
                              title: Text('Updates',style: TextStyle(fontFamily: 'Montserrat',color: thm.highcolor),textAlign: TextAlign.center,),
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
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          value: "White",
                          label: "White",
                          style: MenuItemButton.styleFrom(
                            textStyle: TextStyle(fontFamily: 'Montserrat'),
                            foregroundColor: thm.highcolor,
                          ),
                        ),
                        DropdownMenuEntry(
                          value: "Black",
                          label: "Black",
                          style: MenuItemButton.styleFrom(
                            textStyle: TextStyle(fontFamily: 'Montserrat'),
                            foregroundColor: thm.highcolor,
                          ),
                        ),
                        DropdownMenuEntry(
                          value: "Blue",
                          label: "Blue",
                          style: MenuItemButton.styleFrom(
                            textStyle: TextStyle(fontFamily: 'Montserrat'),
                            foregroundColor: thm.highcolor,
                          ),
                        ),
                        DropdownMenuEntry(
                          value: "Lilac",
                          label: "Lilac",
                          style: MenuItemButton.styleFrom(
                            textStyle: TextStyle(fontFamily: 'Montserrat'),
                            foregroundColor: thm.highcolor,
                          ),
                        ),
                        DropdownMenuEntry(
                          value: "Brown",
                          label: "Brown",
                          style: MenuItemButton.styleFrom(
                            textStyle: TextStyle(fontFamily: 'Montserrat'),
                            foregroundColor:
                                thm
                                    .highcolor,
                          ),
                        ),
                      ],
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
                    onPressed: () async {
                      await launchUrl(Uri.parse('https://forms.gle/t852T4DwNzoDN8tH6'));
                    },
                ),
              ),

              Spacer(flex: 1),
              Text(
                "Made by Srijen Raja",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Montserrat',
                  color: thm.textcolor,
                ),
              ),
              Text(
                "srijenapps@gmail.com",
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Montserrat',
                  color: thm.textcolor,
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
      ),
    );
  }
}
