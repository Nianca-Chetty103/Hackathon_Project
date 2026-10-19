import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduvos_app/main.dart';

void main() {
  testWidgets('shows sign-in form and validates required fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EduvosApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsNWidgets(2));

    await tester.ensureVisible(find.byKey(const ValueKey('password-field')));
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('switches to sign-up form and validates its fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const EduvosApp());
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byKey(const ValueKey('full-name-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-password-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('terms-checkbox')), findsOneWidget);

    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('Confirm your password'), findsOneWidget);
  });
}
