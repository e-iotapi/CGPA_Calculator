import 'package:flutter/material.dart';

class Constants {
  String theme;
  Color backcolor;
  Color textcolor;
  Color sepcolor;
  Color highcolor;
  Color cardcolor;
  Color bordcolor;
  Color unscolor;
  Color butcolor;
  Color iconcolor;

  Constants({
    required this.theme,
    required this.backcolor,
    required this.textcolor,
    required this.sepcolor,
    required this.highcolor,
    required this.cardcolor,
    required this.bordcolor,
    required this.unscolor,
    required this.butcolor,
    required this.iconcolor,
  });
}

List<Constants> themes = [
  Constants(
    theme: "White",
    backcolor: Color(0xFFFCF5FD),
    butcolor: Color(0xFFF3EEFC),
    bordcolor: Color(0xFF000000),
    cardcolor: Color(0xFFFCF2FD),
    textcolor: Colors.black87,
    sepcolor: Colors.black38,
    highcolor: Colors.deepPurple,
    unscolor: Color(0xA6463E4D),
    iconcolor: Color(0xEA222122),
  ),
  Constants(
    theme: "Black",
    backcolor: Color(0xFF0D0D0D),
    butcolor: Color(0xFF19191C),
    bordcolor: Color(0xE5DAD7D7),
    //cardcolor: Color(0xFF1D2121),
    cardcolor: Color(0xFF141414),
    //textcolor: Color(0xD2C4571C),
    textcolor: Color(0xFFB6BABE),
    sepcolor: Color(0xFF3B383B),
    highcolor: Colors.deepPurple,
    unscolor: Colors.white38,
    iconcolor: Colors.white38,
  ),
  Constants(
    theme: "Blue",
    backcolor: Color(0xFF01011C),
    butcolor: Color(0xFF0A0A44),
    bordcolor: Color(0xFFFFFFFF),
    //cardcolor: Color(0xFF1D2121),
    cardcolor: Color(0xFF010125),
    //textcolor: Color(0xD2C4571C),
    textcolor: Color(0xFF4090B2),
    sepcolor: Color(0xFF0F2628),
    highcolor: Color(0xFFBF3E0B),
    unscolor: Colors.white38,
    iconcolor: Color(0xFF645E69),
  ),
  Constants(
    theme: "Lilac",
    backcolor: Color(0xFFE5C2EF),
    butcolor: Color(0xFFE1B1EF),
    bordcolor: Color(0xFF0C0C0C),
    cardcolor: Color(0xFFE1BEEC),
    textcolor: Color(0xFF1F1717),
    sepcolor: Color(0xFF757575),
    highcolor: Color(0xFF0D57E1),
    unscolor: Color(0xFF766B80),
    iconcolor: Color(0xE21E1D21),
  ),
  Constants(
    theme: "Coffee",
    backcolor: Color(0xFF77583D),
    butcolor: Color(0xFF85674A),
    bordcolor: Color(0xFF0C0C0C),
    cardcolor: Color(0xFF7E5E42),
    textcolor: Color(0xFF110E0E),
    sepcolor: Color(0xFF0A0A0A),
    highcolor: Color(0xFF311700),
    unscolor: Color(0xFF423223),
    iconcolor: Color(0xFF000000),
  ),
  Constants(
    theme: "Emerald",
    backcolor: Color(0xFF0E4D43),
    butcolor: Color(0xFF136753),
    bordcolor: Color(0xFFCECBCB),
    cardcolor: Color(0xFF0E574C),
    textcolor: Color(0xFFC4D2CB),
    sepcolor: Color(0xFF38936E),
    highcolor: Color(0xFF1EE67B),
    unscolor: Color(0x996D9C8C),
    iconcolor: Color(0xFF9FE1D6),
  ),

  // Constants(
  //   theme: "Sunset",
  //   backcolor: Color(0xFFD98C6A),
  //   butcolor: Color(0xFFDA8E6C),
  //   bordcolor: Color(0xFF8F4A2C),
  //   cardcolor: Color(0xFFD98865),
  //   textcolor: Color(0xFF3E2E29),
  //   sepcolor: Color(0xFF995C2F),
  //   highcolor: Color(0xFFB05A2C),
  //   unscolor: Color(0xFF8F6445),
  //   iconcolor: Color(0xFF4B372D),
  // ),

  // Constants(
  //   theme: "Ocean",
  //   backcolor: Color(0xFF174D85),
  //   butcolor: Color(0xFF2A69A6),
  //   bordcolor: Color(0xFF6794B8),
  //   cardcolor: Color(0xFF2564A6),
  //   textcolor: Color(0xFFE3E8EB),
  //   sepcolor: Color(0xFF3E7499),
  //   highcolor: Color(0xFFED6A5A),
  //   unscolor: Color(0x667297AD),
  //   iconcolor: Color(0xFFABC6D9),
  // ),

  Constants(
    theme: "Cyberpunk",
    backcolor: Color(0xFF2E1A44),
    butcolor: Color(0xFF421F58),
    bordcolor: Color(0xFF6C597E),
    cardcolor: Color(0xFF361F4F),
    textcolor: Color(0xFFD381BB),
    sepcolor: Color(0xFF7F3E75),
    highcolor: Color(0xFFD4A5E1),
    unscolor: Color(0x99765C85),
    iconcolor: Color(0xFF9A5B95),
  ),

  Constants(
    theme: "Mint",
    backcolor: Color(0xFFB3D7D1),
    butcolor: Color(0xFFA2C8C3),
    bordcolor: Color(0xFF5D7D7B),
    cardcolor: Color(0xFFABD2CE),
    textcolor: Color(0xFF294F4B),
    sepcolor: Color(0xFF3A4F4D),
    highcolor: Color(0xFF053F3C),
    unscolor: Color(0xFF6F7E7B),
    iconcolor: Color(0xFF486B68),
  ),
  /*Constants(
    theme: "Brown",
    backcolor: Color(0xFF77583D),
    butcolor: Color(0xFF86694C),
    bordcolor: Color(0xFF0C0C0C),
    cardcolor: Color(0xFF7E5E42),
    textcolor: Color(0xFF1F1717),
    sepcolor: Color(0xFF1C1C1C),
    highcolor: Color(0xFF311700),
    unscolor: Color(0xFF423223),
    iconcolor: Color(0xE21E1D21),
  ),*/
];
