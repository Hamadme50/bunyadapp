import 'package:bunyad/ui/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({String? email}) => ProviderScope(
      child: MaterialApp(home: ForgotPasswordScreen(email: email)),
    );

void main() {
  testWidgets('the address from the login screen is carried over', (tester) async {
    await tester.pumpWidget(_host(email: 'bilal@example.com'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot your password?'), findsOneWidget);
    // Typing the address a second time, right after a failed sign-in, is the
    // thing this screen most needs to avoid.
    expect(find.text('bilal@example.com'), findsOneWidget);
  });

  testWidgets('an address that is obviously not one is refused before any call', (tester) async {
    await tester.pumpWidget(_host(email: 'not-an-address'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send the link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the email address on your account.'), findsOneWidget);
    // Still on the form — nothing was sent, so nothing should claim it was.
    expect(find.text('On its way'), findsNothing);
  });

  testWidgets('an empty address is refused too', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send the link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the email address on your account.'), findsOneWidget);
  });
}
