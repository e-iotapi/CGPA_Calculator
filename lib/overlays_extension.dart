part of 'home_page.dart';
// ignore_for_file: invalid_use_of_protected_member



extension OverlaysExtension on _MyHomePageState {
  Widget buildCourseDetailSheet(double wid, double hei, List<Course> sitems) {
    return AnimatedSwitcher(
              duration: Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child:
                  _isCourseCardOpen
                      ? Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: !_isClosingCourse ? 0.6 : 0.0,
                            duration: Duration(milliseconds: 100),
                            child: GestureDetector(
                              onTap: () async {
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
                                  _isClosingCourse = true;
                                });
                                Future.delayed(Duration(milliseconds: 100));
                                setState(() {
                                  _isCourseCardOpen = false;
                                  _isClosingCourse = false;
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
                              scale: _isCourseCardOpen ? 1.0 : 0.8,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              child: Card(
                                key: ValueKey("open"),
                                color: thm.cardcolor,
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
                                                color: thm.textcolor,
                                              ),
                                            ),
                                            Text(
                                              sitems[tapid].id.split(" ")[1],
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.normal,
                                                fontFamily: 'Montserrat',
                                                color: thm.textcolor,
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              electiveFinder(
                                                sitems[tapid].elective,
                                              ),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                fontFamily: 'Montserrat',
                                                color: thm.textcolor,
                                              ),
                                            ),
                                          ],
                                        ),
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
                                                  color: thm.bordcolor,
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
                                                    color: thm.textcolor,
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
                                                          color: thm.bordcolor,
                                                          width: 1.0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          "    $credits1    "
                                                              .replaceAll(
                                                                '.0',
                                                                '',
                                                              ),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontFamily:
                                                                'Montserrat',
                                                            fontSize: 22,
                                                            color:
                                                                thm.textcolor,
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
                                                          color: thm.textcolor,
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
                                                          enabledBorder:
                                                              OutlineInputBorder(
                                                                borderSide:
                                                                    BorderSide(
                                                                      color:
                                                                          thm.bordcolor,
                                                                      width: 1,
                                                                    ),
                                                              ),
                                                          focusedBorder:
                                                              OutlineInputBorder(
                                                                borderSide:
                                                                    BorderSide(
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
                                                          backgroundColor:
                                                              WidgetStateProperty.all(
                                                                thm.backcolor,
                                                              ),
                                                        ),
                                                        dropdownMenuEntries:
                                                            grades.map<
                                                              DropdownMenuEntry<
                                                                String
                                                              >
                                                            >((String value) {
                                                              return DropdownMenuEntry<
                                                                String
                                                              >(
                                                                value: value,
                                                                label: value,
                                                                style: MenuItemButton.styleFrom(
                                                                  textStyle: TextStyle(
                                                                    fontFamily:
                                                                        'Montserrat',
                                                                  ),
                                                                  foregroundColor:
                                                                      thm.textcolor,
                                                                ),
                                                              );
                                                            }).toList(),
                                                        onSelected: (
                                                          value,
                                                        ) async {
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
                                                              // await removeCourseById(
                                                              //   "$addcourse $addcourseid",
                                                              // );
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
                                                                selectedelective =
                                                                    "None";
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
                                                                selectedelective =
                                                                    "None";
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
                                                                    fontSize:
                                                                        16,
                                                                  ),
                                                                  "Select Profile First",
                                                                ),
                                                                duration:
                                                                    Duration(
                                                                      seconds:
                                                                          3,
                                                                    ),
                                                              ),
                                                            );
                                                          }
                                                          setState(() {
                                                            if (_isGradeChanged) {
                                                              selecteddiscipline =
                                                                  selecteddiscipline;
                                                              batch = batch;
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
                                                                        ) => course.id.startsWith(
                                                                          "AN" +
                                                                              ' ',
                                                                        ),
                                                                      )
                                                                      .map(
                                                                        (
                                                                          course,
                                                                        ) => course.id.replaceFirst(
                                                                          "AN" +
                                                                              ' ',
                                                                          '',
                                                                        ),
                                                                      )
                                                                      .toList();
                                                              dropdownid.sort(
                                                                (a, b) =>
                                                                    a.compareTo(
                                                                      b,
                                                                    ),
                                                              );
                                                              sort(sitems,currentsort);
                                                              _isCourseCardOpen =
                                                                  false;
                                                              _isGradeChanged =
                                                                  false;
                                                            } else {
                                                              sort(sitems,currentsort);
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
                                                        child: Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                        ),
                                                        // Image.asset(
                                                        //   'images/trash.png',
                                                        //   color: Colors.red,
                                                        // ),
                                                      ),

                                                      onPressed: () async {
                                                        await removeCourseById(
                                                          "$addcourse $addcourseid",
                                                        );
                                                        setState(() {
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
                                                          sort(sitems,currentsort);
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
                      : SizedBox.shrink(key: ValueKey("closed")),
            );
  }

  Widget buildSearchOverlay(double wid, double hei, List<Course> sitems) {
    return AnimatedSwitcher(
              duration: Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child:
                  _isCardOpen
                      ? Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: _isClosing ? 0.0 : 0.6,
                            duration: Duration(milliseconds: 500),
                            child: GestureDetector(
                              onTap: () async {
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
                                  _isClosing = true;
                                });
                                Future.delayed(Duration(milliseconds: 500));
                                setState(() {
                                  _isClosing = false;
                                  _isCardOpen = false;
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
                              scale: _isClosing ? 0 : 1.0,
                              duration: Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Card(
                                key: ValueKey('open'),
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
                                                  color: thm.textcolor,
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
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
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
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm.backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries:
                                                    depts
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
                                                                  thm.textcolor,
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
                                                  color: thm.textcolor,
                                                ),
                                                onSelected: (value) {
                                                  setState(() {
                                                    addcourseid = value!;
                                                    electiveSetter();
                                                  });
                                                },
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
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
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm.backcolor,
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
                                                                  thm.textcolor,
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
                                              color: thm.textcolor,
                                            ),
                                          ),
                                          child: Theme(
                                            data: Theme.of(context).copyWith(
                                              inputDecorationTheme:
                                                  InputDecorationTheme(
                                                    labelStyle: TextStyle(
                                                      fontFamily: "Montserrat",
                                                      color: thm.textcolor,
                                                    ),
                                                    hintStyle: TextStyle(
                                                      fontFamily: 'Montserrat',
                                                      color: thm.textcolor,
                                                    ),
                                                    border: InputBorder.none,
                                                    focusedBorder:
                                                        InputBorder.none,
                                                    enabledBorder:
                                                        InputBorder.none,
                                                  ),
                                              textSelectionTheme:
                                                  TextSelectionThemeData(
                                                    cursorColor: thm.textcolor,
                                                    selectionColor:
                                                        thm.textcolor,
                                                    selectionHandleColor:
                                                        thm.textcolor,
                                                  ),
                                            ),
                                            child: SizedBox(
                                              width: wid * 0.8,
                                              child: SearchAnchor.bar(
                                                barSide: WidgetStatePropertyAll(
                                                  BorderSide(
                                                    color: thm.bordcolor,
                                                    width: 1,
                                                  ),
                                                ),
                                                barElevation:
                                                    WidgetStateProperty.all(0),
                                                viewConstraints: BoxConstraints(
                                                  minHeight: 0,
                                                  maxHeight: hei * 0.3,
                                                ),
                                                barTextStyle:
                                                    WidgetStateProperty.resolveWith(
                                                      (states) {
                                                        if (states.contains(
                                                          WidgetState.focused,
                                                        ))
                                                          return TextStyle(
                                                            fontFamily:
                                                                "Montserrat",
                                                            color:
                                                                thm.textcolor,
                                                          );
                                                        return TextStyle(
                                                          fontFamily:
                                                              "Montserrat",
                                                          color: thm.textcolor,
                                                        );
                                                      },
                                                    ),
                                                barBackgroundColor:
                                                    WidgetStateProperty.all(
                                                      thm.backcolor,
                                                    ),
                                                viewBackgroundColor:
                                                    (selected_theme == "Black")
                                                        ? Color(0xFF3F3C3C)
                                                        : (selected_theme ==
                                                            "Blue")
                                                        ? Color(0xFF2E2E50)
                                                        : thm.backcolor,
                                                barHintText: 'Search Courses',
                                                barHintStyle:
                                                    WidgetStateProperty.all(
                                                      TextStyle(
                                                        color: thm.textcolor,
                                                        fontFamily:
                                                            'Montserrat',
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
                                                          color: thm.textcolor,
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
                                              width: wid * 0.62,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: thm.bordcolor,
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
                                                    color: thm.textcolor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                            Container(
                                              height: hei * 0.08,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: thm.bordcolor,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "    $credits1    "
                                                      .replaceAll('.0', ''),
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 22,
                                                    color: thm.textcolor,
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
                                                    color: thm.textcolor,
                                                  ),
                                                  initialSelection:
                                                      (selectedelective ==
                                                              "None")
                                                          ? "CDCN"
                                                          : selectedelective,
                                                  inputDecorationTheme: InputDecorationTheme(
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
                                                            width: 1,
                                                          ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
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
                                                    backgroundColor:
                                                        WidgetStateProperty.all(
                                                          thm.backcolor,
                                                        ),
                                                  ),
                                                  dropdownMenuEntries: [
                                                    DropdownMenuEntry(
                                                      value: "CDCN",
                                                      label: "None",
                                                      style:
                                                          MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
                                                          ),
                                                    ),
                                                    DropdownMenuEntry(
                                                      value: "CDC2",
                                                      label:
                                                          "CDC (" +
                                                          selecteddiscipline
                                                              .substring(2, 4) +
                                                          ")",
                                                      style:
                                                          MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
                                                          ),
                                                    ),
                                                    DropdownMenuEntry(
                                                      value: "Open Elective",
                                                      label: "Open Elective",
                                                      style:
                                                          MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
                                                          ),
                                                    ),
                                                    DropdownMenuEntry(
                                                      value:
                                                          "Humanity Elective",
                                                      label:
                                                          "Humanity Elective",
                                                      style:
                                                          MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
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
                                                      style:
                                                          MenuItemButton.styleFrom(
                                                            textStyle: TextStyle(
                                                              fontFamily:
                                                                  'Montserrat',
                                                            ),
                                                            foregroundColor:
                                                                thm.textcolor,
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
                                                              thm.textcolor,
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
                                                              thm.textcolor,
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
                                                    color: thm.textcolor,
                                                  ),
                                                  initialSelection: "A",
                                                  inputDecorationTheme: InputDecorationTheme(
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
                                                            width: 1,
                                                          ),
                                                        ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color:
                                                                thm.bordcolor,
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
                                                    backgroundColor:
                                                        WidgetStateProperty.all(
                                                          thm.backcolor,
                                                        ),
                                                  ),
                                                  dropdownMenuEntries:
                                                      grades
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
                                                                    thm.textcolor,
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                  onSelected: (value) {
                                                    selectedgrade =
                                                        reversegradecalc(
                                                          value!,
                                                        );
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
                                                backgroundColor: thm.butcolor,
                                                child: Text(
                                                  "Add Course",
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontSize: 22,
                                                    color: thm.highcolor,
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
                                                        selectedelective =
                                                            "None";
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
                                                        selectedelective =
                                                            "None";
                                                      }

                                                      selectedgrade = 10;
                                                      currentsem = currentsem;
                                                      selecteddiscipline =
                                                          selecteddiscipline;
                                                      batch = batch;
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
                                                      sort(sitems,currentsort);
                                                    }
                                                  });
                                                  setState(() {
                                                    _isClosing =
                                                        true; // Start close animation
                                                  });
                                                  Future.delayed(
                                                    const Duration(
                                                      milliseconds: 500,
                                                    ),
                                                    () {
                                                      if (!mounted) return;
                                                      setState(() {
                                                        _isCardOpen = false;
                                                        _isClosing = false;
                                                      });
                                                    },
                                                  );
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
                      : SizedBox.shrink(key: ValueKey('closed')),
            );
  }

  Widget buildAddCourseDialog(double wid, double hei, List<Course> sitems) {
    return AnimatedScale(
                              scale: !degree_selected ? 1.0 : 0.8,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              child: Card(
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
                                                color: thm.textcolor,
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
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
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
                                                textStyle: TextStyle(
                                                  fontSize: 16,
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.normal,
                                                  color: thm.textcolor,
                                                ),
                                                initialSelection: "",
                                                menuStyle: MenuStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm.backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries:
                                                    degreelist
                                                        .where(
                                                          (id) => id.startsWith(
                                                            "B",
                                                          ),
                                                        )
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
                                                                  thm.textcolor,
                                                            ),
                                                          ),
                                                        )
                                                        .toList() +
                                                    [
                                                      DropdownMenuEntry(
                                                        value: "B-",
                                                        label: "Other",
                                                        style: MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                      ),
                                                      DropdownMenuEntry(
                                                        value: "--",
                                                        label: "None",
                                                        style: MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                      ),
                                                    ],
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
                                                color: thm.textcolor,
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
                                                  color: thm.textcolor,
                                                ),
                                                initialSelection: "",
                                                inputDecorationTheme:
                                                    InputDecorationTheme(
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
                                                              width: 1,
                                                            ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  thm.bordcolor,
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
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                        thm.backcolor,
                                                      ),
                                                ),
                                                dropdownMenuEntries:
                                                    degreelist
                                                        .where(
                                                          (id) => id.startsWith(
                                                            "A",
                                                          ),
                                                        )
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
                                                                  thm.textcolor,
                                                            ),
                                                          ),
                                                        )
                                                        .toList() +
                                                    [
                                                      DropdownMenuEntry(
                                                        value: "--",
                                                        label: "Other",
                                                        style: MenuItemButton.styleFrom(
                                                          textStyle: TextStyle(
                                                            fontFamily:
                                                                'Montserrat',
                                                          ),
                                                          foregroundColor:
                                                              thm.textcolor,
                                                        ),
                                                      ),
                                                    ],
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
                                        Row(
                                          children: [
                                            Text(
                                              "Batch",
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 18,
                                                color: thm.textcolor,
                                              ),
                                            ),
                                            Spacer(flex: 1),
                                            SizedBox(
                                              width: 30,
                                              child: TextField(
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: <
                                                  TextInputFormatter
                                                >[
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                controller: _batchController1,
                                                onSubmitted: (value) {
                                                  if (_batchController1
                                                      .text
                                                      .isNotEmpty) {
                                                    batch = int.parse(value);
                                                  }
                                                  setdis();
                                                },
                                                onChanged: (value) {
                                                  if (_batchController1
                                                      .text
                                                      .isNotEmpty) {
                                                    batch = int.parse(value);
                                                  }
                                                  setdis();
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 5),
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
                                                    await setdis();
                                                    await initializeCourses();
                                                    sort(sitems,currentsort);
                                                    setState(() {
                                                      selectedgrade = 10;
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
                                                      sort(sitems,currentsort);
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
                            );
  }

}
