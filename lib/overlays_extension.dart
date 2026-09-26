part of 'home_page.dart';
// ignore_for_file: invalid_use_of_protected_member



extension OverlaysExtension on _MyHomePageState {
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
                                                    offeredDegrees
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
                                                    offeredDegrees
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
