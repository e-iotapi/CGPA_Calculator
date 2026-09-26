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
                                    height: 372.0,
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
                                            SizedBox(height: 72.0),
                                            Container(
                                              margin: EdgeInsets.only(right: 0),
                                              height: 60.0,
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
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                                  child: Text(
                                                    name1,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: 'Montserrat',
                                                      fontSize: 16,
                                                      color: thm.textcolor,
                                                    ),
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
                                                      height: 60.0,
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
                                              height: 60.0,
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
                                    height: 360.0,
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
                                                            height: 56.0,
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
                                                            height: 56.0,
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
                                              height: 60.0,
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
