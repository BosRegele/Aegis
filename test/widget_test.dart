// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:firster/Auth/login_page_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Login screen renders expected fields', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: LoginPageFirestore()));

    expect(find.text('Autentificare'), findsOneWidget);
    expect(find.text('Nume de utilizator'), findsOneWidget);
    expect(find.text('Parola'), findsOneWidget);
    expect(find.text('Conectează-te'), findsOneWidget);
  });
}
