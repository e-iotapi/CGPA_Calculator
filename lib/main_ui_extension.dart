part of 'home_page.dart';
// ignore_for_file: invalid_use_of_protected_member

extension MainUiExtension on _MyHomePageState {
  Widget buildMainUI(double wid, double hei, List<Course> sitems) {
    return Center(
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
                      key: ValueKey(_dropdownResetKey),
                      initialSelection: currentsem,
                      onSelected: (String? value) {
                        if (value == "Off") {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) => Offshoot(),
                                ),
                              )
                              .then((_) {
                                setState(() {
                                  // Force dropdown reset
                                  _dropdownResetKey++;
                                });
                              });
                          ;
                        } else {
                          setState(() {
                            currentsem = value!;
                            sgpa = sgcalc(value);
                            cgpa = cgcalc();
                          });
                        }
                      },
                      textAlign: TextAlign.center,
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        color: thm.textcolor,
                      ),
                      inputDecorationTheme: InputDecorationTheme(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: thm.bordcolor,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: thm.bordcolor,
                            width: 1,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: thm.bordcolor,
                            width: 1,
                          ),
                        ),
                      ),
                      menuStyle: MenuStyle(
                        backgroundColor: WidgetStateProperty.all(thm.backcolor),
                      ),
                      dropdownMenuEntries:
                          sems
                              .map(
                                (id) => DropdownMenuEntry(
                                  value: id,
                                  label: id,
                                  style: MenuItemButton.styleFrom(
                                    textStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                    ),
                                    foregroundColor: thm.textcolor,
                                  ),
                                ),
                              )
                              .toList() +
                          ((selecteddiscipline.startsWith("B"))
                              ? [
                                DropdownMenuEntry(
                                  value: "ST 2",
                                  label: "ST 2",
                                  style: MenuItemButton.styleFrom(
                                    textStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                    ),
                                    foregroundColor: thm.textcolor,
                                  ),
                                ),
                                DropdownMenuEntry(
                                  value: "5 - 1",
                                  label: "5 - 1",
                                  style: MenuItemButton.styleFrom(
                                    textStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                    ),
                                    foregroundColor: thm.textcolor,
                                  ),
                                ),
                                DropdownMenuEntry(
                                  value: "5 - 2",
                                  label: "5 - 2",
                                  style: MenuItemButton.styleFrom(
                                    textStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                    ),
                                    foregroundColor: thm.textcolor,
                                  ),
                                ),
                              ]
                              : []) +
                          [
                            DropdownMenuEntry(
                              value: "Off",
                              label: "Offshoot",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                          ],
                    ),
                  ),
                  Spacer(flex: 1),
                  Row(
                    children: [
                      if (kIsWeb)
                      SizedBox(height: 35,width: 70,child:
                      FloatingActionButton(
                          elevation: 0,
                          focusElevation: 0,
                          hoverElevation: 0,
                          highlightElevation: 0,
                          disabledElevation: 0,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: thm.iconcolor)
                          ),
                          child: Text(
                            "Install",style: TextStyle(
                            color:
                            thm.iconcolor,
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                          ),
                          ),
                          onPressed: () async {
                            final ua = html.window.navigator
                                .userAgent.toLowerCase();
                            if (ua.contains('android')) {
                              await launchUrl(
                                Uri.parse(
                                    'https://play.google.com/store/apps/details?id=com.srijen.cgpa_calculator'),
                              );
                            }
                            else {
                              try {
                                js.context.callMethod(
                                    'promptInstall');
                              }
                              catch (e) {
                                if (ua.contains('ios') ||
                                    ua.contains('ipad') ||
                                    ua.contains('iphone')) {
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Click on Share => Add to Home Screen => Add",
                                        style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontWeight: FontWeight
                                              .normal,
                                          fontSize: 16,
                                        ),
                                      ),
                                      duration: Duration(
                                          seconds: 4),
                                    ),
                                  );
                                }
                                else if (ua.contains('win') ||
                                    ua.contains('mac') ||
                                    ua.contains('linux')) {
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Click on Settings => Cast, Save and Share => Install Page as app",
                                        style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontWeight: FontWeight
                                              .normal,
                                          fontSize: 16,
                                        ),
                                      ),
                                      duration: Duration(
                                          seconds: 4),
                                    ),
                                  );
                                }
                                else {
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Click on Share => Add to Home Screen => Add",
                                        style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontWeight: FontWeight
                                              .normal,
                                          fontSize: 16,
                                        ),
                                      ),
                                      duration: Duration(
                                          seconds: 4),
                                    ),
                                  );
                                }
                              }
                            }
                          }
                      ),),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(3.1416),
                        child: Transform.scale(
                          scale: 1.2,
                          child: FloatingActionButton(
                            heroTag: 'nav_analytics_btn',
                            elevation: 0,
                            focusElevation: 0,
                            hoverElevation: 0,
                            highlightElevation: 0,
                            disabledElevation: 0,
                            backgroundColor: Colors.transparent,
                            shape: CircleBorder(),
                            child: Icon(
                              Icons.insert_chart_rounded,
                              color: thm.iconcolor,
                            ),
                            onPressed: () {
                              setState(() {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => Analytics(),
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
                          heroTag: 'nav_settings_btn',
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
                            color: thm.iconcolor,
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
                                  thm = themes.firstWhere(
                                    (theme) => theme.theme == selected_theme,
                                  );
                                  //await settheme();
                                  profile1n = profile1n;
                                  profile2n = profile2n;
                                  //await setprof();
                                  currentsem = currentsem;
                                  batch = batch;
                                  selecteddiscipline = selecteddiscipline;
                                  await setdis();
                                  await initializeCourses();
                                  setnavcolor();
                                  setState(() {
                                    thm = themes.firstWhere(
                                      (theme) => theme.theme == selected_theme,
                                    );
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
                            color: thm.textcolor,
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
                            color: thm.cardcolor,
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
                                crossAxisAlignment: CrossAxisAlignment.center,
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
                                            fontWeight: FontWeight.normal,
                                            color: thm.textcolor,
                                          ),
                                        ),
                                        Text(
                                          "Credits (S)",
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                            color: thm.textcolor,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "CGPA",
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 20,
                                            fontWeight: FontWeight.normal,
                                            color: thm.textcolor,
                                          ),
                                        ),
                                        Text(
                                          "Credits (C)",
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                            color: thm.textcolor,
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
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Text(
                                                  (sgcomp(
                                                            currentsem,
                                                          ).split(" ")[0] !=
                                                          "0")
                                                      ? sgcomp(
                                                        currentsem,
                                                      ).split(" ")[0]
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 18,
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                                Text(
                                                  ("$scred1" != "0")
                                                      ? "$scred1".replaceAll(
                                                        '.0',
                                                        '',
                                                      )
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 14,
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                                SizedBox(height: 12),
                                                Text(
                                                  (cgcomp().split(" ")[0] !=
                                                          "0")
                                                      ? cgcomp().split(" ")[0]
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 18,
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                                Text(
                                                  ("$ccred1" != "0")
                                                      ? "$ccred1".replaceAll(
                                                        '.0',
                                                        '',
                                                      )
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 14,
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            heightFactor: 0.98,
                                            child: Container(
                                              width: 1,
                                              color: thm.sepcolor,
                                              margin: EdgeInsets.symmetric(
                                                horizontal: 2,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Text(
                                                  (sgcomp(
                                                            currentsem,
                                                          ).split(" ")[1] !=
                                                          "0")
                                                      ? sgcomp(
                                                        currentsem,
                                                      ).split(" ")[1]
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 18,
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                                Text(
                                                  ("$scred2" != "0")
                                                      ? "$scred2".replaceAll(
                                                        '.0',
                                                        '',
                                                      )
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 14,
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                                SizedBox(height: 12),
                                                Text(
                                                  (cgcomp().split(" ")[1] !=
                                                          "0")
                                                      ? cgcomp().split(" ")[1]
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 18,
                                                    color: thm.highcolor,
                                                  ),
                                                ),
                                                Text(
                                                  ("$ccred2" != "0")
                                                      ? "$ccred2".replaceAll(
                                                        '.0',
                                                        '',
                                                      )
                                                      : "-",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 14,
                                                    color: thm.highcolor,
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
                                    color: thm.textcolor,
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
                                    color: thm.textcolor,
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
                              color: thm.textcolor,
                              fontSize: (selectedprofile != 3) ? 34 : 28,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          Text(
                            (selectedprofile == 1)
                                ? "$scred1".replaceAll('.0', '')
                                : (selectedprofile == 2)
                                ? "$scred2".replaceAll('.0', '')
                                : "$scred1,$scred2".replaceAll('.0', ''),
                            style: TextStyle(
                              color: thm.textcolor,
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
                                    color: thm.textcolor,
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
                                    color: thm.textcolor,
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
                              color: thm.textcolor,
                              fontSize: (selectedprofile != 3) ? 34 : 28,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          Text(
                            (selectedprofile == 1)
                                ? "$ccred1".replaceAll('.0', '')
                                : (selectedprofile == 2)
                                ? "$ccred2".replaceAll('.0', '')
                                : "$ccred1,$ccred2".replaceAll('.0', ''),
                            style: TextStyle(
                              color: thm.textcolor,
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
              // SizedBox(height: 4),
              if (selectedprofile != 3)
                Row(
                  children: [
                    Spacer(flex: 1),
                    SizedBox(
                      height: hei * 0.05,
                      width: wid * 0.50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: thm.bordcolor),
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
                            color: thm.highcolor,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2),
                    Spacer(flex: 1),
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
                          width: wid * 0.31,
                          onSelected: (value) {
                            setState(() {
                              currentsort = value!;
                              sort(sitems, currentsort);
                            });
                          },
                          initialSelection: currentsort,
                          textStyle: TextStyle(
                            fontSize: (selectedprofile != 3) ? 12 : 0,
                            fontWeight: FontWeight.normal,
                            fontFamily: "Montserrat",
                            color: thm.textcolor,
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: thm.bordcolor,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: thm.bordcolor,
                                width: 1,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: thm.bordcolor,
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
                              leadingIcon: Icon(
                                Icons.keyboard_arrow_down_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Asc Credits",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                            DropdownMenuEntry(
                              value: "Sort by Credits(Des)",
                              enabled: (selectedprofile != 3),

                              leadingIcon: Icon(
                                Icons.keyboard_arrow_up_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Desc Credits",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                            DropdownMenuEntry(
                              enabled: (selectedprofile != 3),
                              value: "Sort by Grades(Asc)",

                              leadingIcon: Icon(
                                Icons.keyboard_arrow_down_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Asc Grades",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                            DropdownMenuEntry(
                              enabled: (selectedprofile != 3),
                              value: "Sort by Grades(Des)",

                              leadingIcon: Icon(
                                Icons.keyboard_arrow_up_outlined,
                                color: thm.textcolor,
                              ),
                              label: "Desc Grades",
                              style: MenuItemButton.styleFrom(
                                textStyle: TextStyle(fontFamily: 'Montserrat'),
                                foregroundColor: thm.textcolor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 1.4,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: thm.backcolor,
                          shape: CircleBorder(),
                        ),
                        onPressed: () async {
                          final sitemsAsMaps =
                              sitems
                                  .map(
                                    (course) => {
                                      'credits': course.credits,
                                      'name': course.title,
                                      'grade':
                                          (selectedprofile == 1)
                                              ? course.grade1
                                              : course.grade2,
                                    },
                                  )
                                  .toList();
                          var imgpath = await saveDataAsImage(
                            isOffshoot: false,
                            sitemsAsMaps,
                            semester: currentsem,
                            thisSemCredits:
                                (selectedprofile == 1) ? scred1 : scred2,
                            totalCredits:
                                (selectedprofile == 1) ? ccred1 : ccred2,
                            gpa: sgcalc(currentsem),
                            cgpa: cgcalc(),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "$imgpath",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.save_alt_outlined,
                          color: thm.textcolor,
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: hei * 0.01),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      if (details.primaryVelocity! < 0 && selectedprofile < 3) {
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
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(
                            (!_isrightswipe)
                                ? (MediaQuery.of(context).size.width > wid)
                                    ? -0.10
                                    : -1.0
                                : (MediaQuery.of(context).size.width > wid)
                                ? 0.10
                                : 1.0,
                            0.0,
                          ),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: NotificationListener<ScrollNotification>(
                      key: ValueKey(selectedprofile),
                      onNotification: (ScrollNotification notification) {
                        if (selectedprofile == 3 || selectedprofile == 4)
                          return false;

                        if (notification.metrics.pixels < 0) {
                          pullOverscrollNotifier.value =
                              notification.metrics.pixels;
                        } else if (pullOverscrollNotifier.value != 0) {
                          pullOverscrollNotifier.value = 0;
                        }

                        bool isPullingDown = false;
                        if (notification.metrics.pixels < -60) {
                          if (notification is ScrollUpdateNotification &&
                              notification.dragDetails != null) {
                            isPullingDown = true;
                          } else if (notification is OverscrollNotification &&
                              notification.dragDetails != null) {
                            isPullingDown = true;
                          }
                        }

                        if (isPullingDown) {
                          if (_pullSession == 0) {
                            _pullSession =
                                DateTime.now().millisecondsSinceEpoch;
                            final int currentSession = _pullSession;
                            Future.delayed(
                              const Duration(milliseconds: 1000),
                              () async {
                                if (_pullSession == currentSession && mounted) {
                                  _pullSession = 0; // Prevent multiple popups
                                  bool? clear = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        backgroundColor: thm.cardcolor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: Text(
                                          "Clear Grades",
                                          style: TextStyle(
                                            color: thm.textcolor,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: "Montserrat",
                                          ),
                                        ),
                                        content: Text(
                                          "Are you sure you want to clear all grades for this semester?",
                                          style: TextStyle(
                                            color: thm.textcolor,
                                            fontFamily: "Montserrat",
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                            child: Text(
                                              "Cancel",
                                              style: TextStyle(
                                                color: thm.textcolor,
                                                fontFamily: "Montserrat",
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                            child: Text(
                                              "Clear",
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Montserrat",
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (clear == true) {
                                    await clearSemesterGrades(
                                      currentsem,
                                      selectedprofile,
                                    );
                                    setState(() {
                                      sgpa = sgcalc(currentsem);
                                      cgpa = cgcalc();
                                    });
                                  }
                                }
                              },
                            );
                          }
                        } else {
                          _pullSession = 0;
                        }
                        return false;
                      },
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ValueListenableBuilder<double>(
                            valueListenable: pullOverscrollNotifier,
                            builder: (context, val, child) {
                              return Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: val < 0 ? -val : 0,
                                child: Container(
                                  alignment: Alignment.center,
                                  child:
                                      val < -80
                                          ? Text(
                                            "Hold to clear grades",
                                            style: TextStyle(
                                              color: thm.textcolor.withOpacity(
                                                0.5,
                                              ),
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                          : const SizedBox(),
                                ),
                              );
                            },
                          ),
                          ListView.builder(
                            padding: EdgeInsets.only(top: 0),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            itemCount: sitems.length,
                            itemBuilder: (BuildContext context, int index) {
                              OverlayEntry? gradeOverlayEntry;
                              OverlayEntry? gradeBarrierEntry;
                              ValueNotifier<int> gradeIndexNotifier =
                                  ValueNotifier<int>(0);
                              FixedExtentScrollController?
                              gradeScrollController;
                              double initialY = 0;
                              int initialItemIndex = 0;

                              return (selectedprofile != 4)
                                  ? Card(
                                    color: thm.cardcolor,
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
                                            color: thm.textcolor,
                                          ),
                                        ),
                                      ),
                                      subtitle: Text(
                                        sitems[index].id,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.normal,
                                          color: thm.textcolor,
                                        ),
                                      ),
                                      leading:
                                          (selectedprofile != 3)
                                              ? Stack(
                                                children: [
                                                  SizedBox(
                                                    width: wid * 0.13,
                                                    child: Container(
                                                      color: Colors.transparent,
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
                                                                        .toString()
                                                                        .replaceAll(
                                                                          '.0',
                                                                          '',
                                                                        ),
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          21.5,
                                                                      fontFamily:
                                                                          'Montserrat',
                                                                      color:
                                                                          thm.textcolor,
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
                                                                          thm.textcolor,
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
                                                      color: thm.sepcolor,
                                                    ),
                                                  ),
                                                ],
                                              )
                                              : null,
                                      trailing:
                                          (selectedprofile != 3)
                                              ? Listener(
                                                onPointerDown: (_) {
                                                  if (gradeOverlayEntry != null) {
                                                    gradeOverlayEntry!.remove();
                                                    gradeOverlayEntry = null;
                                                  }
                                                  if (gradeScrollController !=
                                                      null) {
                                                    gradeScrollController!
                                                        .dispose();
                                                    gradeScrollController =
                                                        null;
                                                  }
                                                },
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onLongPressStart: (details) {
                                                    int currentGrade =
                                                        selectedprofile == 1
                                                            ? sitems[index].grade1
                                                            : sitems[index]
                                                                .grade2;
                                                    String currentGradeStr =
                                                        gradecalc(currentGrade);
                                                    initialItemIndex = grades
                                                        .indexOf(currentGradeStr);
                                                    if (initialItemIndex == -1 &&
                                                        currentGradeStr == "–")
                                                      initialItemIndex = grades
                                                          .indexOf("GD");
                                                    if (initialItemIndex == -1)
                                                      initialItemIndex = 0;

                                                    gradeIndexNotifier.value =
                                                        initialItemIndex;
                                                    gradeScrollController =
                                                        FixedExtentScrollController(
                                                          initialItem:
                                                              initialItemIndex,
                                                        );
                                                    initialY =
                                                        details.globalPosition.dy;

                                                    gradeOverlayEntry = OverlayEntry(
                                                      builder: (context) {
                                                        return Positioned(
                                                          left:
                                                              details
                                                                  .globalPosition
                                                                  .dx -
                                                              60,
                                                          top:
                                                              details
                                                                  .globalPosition
                                                                  .dy -
                                                              125,
                                                          child: Material(
                                                            color:
                                                                Colors
                                                                    .transparent,
                                                            child: Container(
                                                              width: 120,
                                                              height: 250,
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    thm.cardcolor,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      15,
                                                                    ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color:
                                                                        Colors
                                                                            .black26,
                                                                    blurRadius:
                                                                        10,
                                                                  ),
                                                                ],
                                                              ),
                                                              child: ListWheelScrollView.useDelegate(
                                                                controller:
                                                                    gradeScrollController,
                                                                itemExtent: 45,
                                                                physics:
                                                                    NeverScrollableScrollPhysics(),
                                                                childDelegate: ListWheelChildBuilderDelegate(
                                                                  childCount:
                                                                      grades
                                                                          .length,
                                                                  builder: (
                                                                    context,
                                                                    i,
                                                                  ) {
                                                                    return ValueListenableBuilder<
                                                                      int
                                                                    >(
                                                                      valueListenable:
                                                                          gradeIndexNotifier,
                                                                      builder: (
                                                                        context,
                                                                        selected,
                                                                        _,
                                                                      ) {
                                                                        bool
                                                                        isSelected =
                                                                            i ==
                                                                            selected;
                                                                        return Center(
                                                                          child: Text(
                                                                            grades[i],
                                                                            style: TextStyle(
                                                                              color:
                                                                                  isSelected
                                                                                      ? thm.highcolor
                                                                                      : thm.textcolor.withOpacity(
                                                                                        0.5,
                                                                                      ),
                                                                              fontSize:
                                                                                  isSelected
                                                                                      ? 24
                                                                                      : 18,
                                                                              fontWeight:
                                                                                  isSelected
                                                                                      ? FontWeight.bold
                                                                                      : FontWeight.normal,
                                                                              fontFamily:
                                                                                  'Montserrat',
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                    void dismissGradePicker() {
                                                      if (gradeBarrierEntry != null) {
                                                        gradeBarrierEntry!.remove();
                                                        gradeBarrierEntry = null;
                                                      }
                                                      if (gradeOverlayEntry != null) {
                                                        gradeOverlayEntry!.remove();
                                                        gradeOverlayEntry = null;
                                                      }
                                                      if (gradeScrollController != null) {
                                                        gradeScrollController!.dispose();
                                                        gradeScrollController = null;
                                                      }
                                                    }
                                                    gradeBarrierEntry = OverlayEntry(
                                                      builder: (_) => Positioned.fill(
                                                        child: Listener(
                                                          behavior: HitTestBehavior.translucent,
                                                          onPointerDown: (_) => dismissGradePicker(),
                                                        ),
                                                      ),
                                                    );
                                                    Overlay.of(context).insertAll([
                                                      gradeBarrierEntry!,
                                                      gradeOverlayEntry!,
                                                    ]);
                                                  },
                                                  onLongPressMoveUpdate: (details) {
                                                    if (gradeScrollController !=
                                                        null) {
                                                      double deltaY =
                                                          details.globalPosition
                                                                  .dy -
                                                              initialY;
                                                      double targetOffset =
                                                          (initialItemIndex *
                                                                  45.0) -
                                                              deltaY;
                                                      double maxOffset =
                                                          (grades.length - 1) *
                                                              45.0;
                                                      targetOffset =
                                                          targetOffset.clamp(
                                                            0.0,
                                                            maxOffset,
                                                          );
                                                      if (gradeScrollController!
                                                          .hasClients) {
                                                        gradeScrollController!
                                                            .jumpTo(targetOffset);
                                                      }
                                                      int newIndex =
                                                          (targetOffset / 45.0)
                                                              .round()
                                                              .clamp(
                                                                0,
                                                                grades.length - 1,
                                                              );
                                                      if (gradeIndexNotifier
                                                              .value !=
                                                          newIndex) {
                                                        gradeIndexNotifier
                                                            .value = newIndex;
                                                      }
                                                    }
                                                  },
                                                  onLongPressEnd: (details) async {
                                                    if (gradeOverlayEntry !=
                                                        null) {
                                                      gradeOverlayEntry!
                                                          .remove();
                                                      gradeOverlayEntry = null;
                                                    }
                                                    if (gradeScrollController !=
                                                        null) {
                                                      gradeScrollController!
                                                          .dispose();
                                                      gradeScrollController =
                                                          null;
                                                    }
                                                    int finalIndex =
                                                        gradeIndexNotifier.value;
                                                    int newGrade =
                                                        reversegradecalc(
                                                          grades[finalIndex],
                                                        );
                                                    Course newCourse = Course(
                                                      elective:
                                                          sitems[index].elective,
                                                      title: sitems[index].title,
                                                      sem: sitems[index].sem,
                                                      id: sitems[index].id,
                                                      discipline:
                                                          sitems[index].discipline,
                                                      grade1:
                                                          selectedprofile == 1
                                                              ? newGrade
                                                              : sitems[index]
                                                                  .grade1,
                                                      grade2:
                                                          selectedprofile == 2
                                                              ? newGrade
                                                              : sitems[index]
                                                                  .grade2,
                                                      credits:
                                                          sitems[index].credits,
                                                    );
                                                    await addOrUpdateCourse(
                                                      newCourse,
                                                    );
                                                    setState(() {});
                                                  },
                                                  onLongPressCancel: () {
                                                    if (gradeOverlayEntry !=
                                                        null) {
                                                      gradeOverlayEntry!
                                                          .remove();
                                                      gradeOverlayEntry = null;
                                                    }
                                                    if (gradeScrollController !=
                                                        null) {
                                                      gradeScrollController!
                                                          .dispose();
                                                      gradeScrollController =
                                                          null;
                                                    }
                                                  },
                                                  child: Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      Padding(
                                                        padding: EdgeInsets.only(
                                                          right:
                                                              wid * (0.120),
                                                        ),
                                                        child: Container(
                                                          width: 1,
                                                          height: 60,
                                                          color: thm.sepcolor,
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
                                                            fontSize: (gradecalc(
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
                                                            color: thm.highcolor,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                              : SizedBox(
                                                width: wid * 0.220,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    SizedBox(
                                                      width: wid * 0.0945,
                                                      child: Text(
                                                        (((sitems[index].grade1 >
                                                                            0)
                                                                        ? gradecalc(
                                                                          sitems[index]
                                                                              .grade1,
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
                                                          color: thm.highcolor,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 1,
                                                      height: 60,
                                                      color: thm.sepcolor,
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
                                                          color: thm.highcolor,
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
                                                sitems[index].id.split(" ")[0];
                                            addcourseid =
                                                sitems[index].id.split(" ")[1];
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
                                        color: thm.textcolor,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
