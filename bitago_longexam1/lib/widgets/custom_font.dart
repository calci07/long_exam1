import 'package:flutter/material.dart';

class CustomFont {
  static TextStyle heading(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineSmall!
      .copyWith(fontFamily: 'Klavika', fontWeight: FontWeight.bold);
  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(fontFamily: 'Frutiger');
}
