import 'package:bunyad/ui/widgets/sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deleting an account erases every project the holder owns and cannot be
/// undone. The typed word is the whole safeguard in front of that, so it is
/// worth pinning down that the button really is dead until it matches.
void main() {
  testWidgets('the confirm button does nothing until the word is typed', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await confirmTypedSheet(
                    context,
                    title: 'Delete your account?',
                    body: 'Your account and every project you own will be erased.',
                    word: 'delete',
                    confirmLabel: 'Delete account',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);

    // Nothing typed: the button is showing, and pressing it is a no-op.
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget, reason: 'dialog should stay open');
    expect(result, isNull);

    // The wrong word is no better.
    await tester.enterText(find.byType(TextField), 'remove');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(result, isNull);

    // The right word, whatever the keyboard did to its case, lets it through.
    await tester.enterText(find.byType(TextField), 'Delete');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('cancelling reports no confirmation', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await confirmTypedSheet(
                    context,
                    title: 'Delete your account?',
                    body: 'Your account and every project you own will be erased.',
                    word: 'delete',
                    confirmLabel: 'Delete account',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Typed correctly, then thought better of it.
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
