import 'package:flutter/material.dart';

const kPink = Color(0xFFFF6F9F);
const kCream = Color(0xFFFFFBF7);
const kLavender = Color(0xFFCBB8FF);
const kInk = Color(0xFF3D314A);

ThemeData buildAppTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: kPink, surface: kCream),
  scaffoldBackgroundColor: kCream,
  useMaterial3: true,
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: kInk,
    displayColor: kInk,
  ),
);
