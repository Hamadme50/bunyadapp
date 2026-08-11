import 'package:bunyad/core/formatting.dart';
import 'package:bunyad/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The formatting rules the screens depend on, and the enum parsing that turns
/// the API's wire values into something typed. Both are pure, so they are worth
/// pinning down without booting the app.
void main() {
  group('money', () {
    test('groups thousands and carries the project currency', () {
      expect(money(16665200, 'Rs'), 'Rs 16,665,200');
      expect(money(1250.5, 'Rs'), 'Rs 1,250.50');
      expect(money(0, 'PKR'), 'PKR 0');
    });

    test('treats a missing amount as zero', () {
      expect(money(null), 'Rs 0');
    });
  });

  group('parseDecimal', () {
    test('reads a number the way a person types it', () {
      expect(parseDecimal('1,250'), 1250);
      expect(parseDecimal(' 84 '), 84);
      expect(parseDecimal('3.5'), 3.5);
    });

    test('blank is null, so an optional number stays optional', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal(null), isNull);
    });

    test('nonsense is NaN, not zero — zero would be a silent wrong answer', () {
      expect(parseDecimal('abc')!.isNaN, isTrue);
    });
  });

  group('dates', () {
    test('parses the API date without a timezone shifting the day', () {
      final date = parseDate('2026-07-12');
      expect(date, DateTime(2026, 7, 12));
      expect(longDate('2026-07-12'), '12 Jul 2026');
    });

    test('splits the timeline day and month', () {
      final parts = dayParts('2026-07-05');
      expect(parts.day, '05');
      expect(parts.month, 'Jul 2026');
    });
  });

  group('plural', () {
    test('agrees with the count', () {
      expect(plural(1, 'expense'), '1 expense');
      expect(plural(3, 'expense'), '3 expenses');
      expect(plural(2, 'person', 'people'), '2 people');
    });
  });

  group('stageDates', () {
    test('prefers the real dates, then the note, then says nothing is set', () {
      expect(
        stageDates(startedOn: '2026-01-05', completedOn: '2026-03-20'),
        '5 Jan 2026 → 20 Mar 2026',
      );
      expect(stageDates(startedOn: '2026-01-05'), 'Started 5 Jan 2026');
      expect(stageDates(plannedNote: 'Planned Sep 2026'), 'Planned Sep 2026');
      expect(stageDates(), 'Not scheduled yet');
    });
  });

  group('models', () {
    test('an absent active flag reads as active, not deactivated', () {
      final user = UserView.fromJson({
        'id': '1',
        'name': 'Hammad Ali',
        'email': 'hammad@example.com',
        'initials': 'HA',
        'role': 'ADMIN',
      });
      expect(user.active, isTrue);
      expect(user.isAdmin, isTrue);
      expect(user.mustChangePassword, isFalse);
    });

    test('access levels carry their rights', () {
      expect(AccessLevel.parse('OWNER')!.canAdminister, isTrue);
      expect(AccessLevel.parse('EDITOR')!.canEdit, isTrue);
      expect(AccessLevel.parse('VIEWER')!.canEdit, isFalse);
      expect(AccessLevel.parse(null), isNull);
    });

    test('a dashboard of one currency can show one total', () {
      DashboardView build(List<String> currencies) => DashboardView.fromJson({
            'user': {'id': '1', 'name': 'A', 'email': 'a@b.c', 'initials': 'A', 'role': 'USER'},
            'totals': {
              'portfolioTotal': 100,
              'projectCount': currencies.length,
              'stagesInProgress': 0,
              'expenseCount': 0,
            },
            'projects': [
              for (final currency in currencies)
                {'id': currency, 'name': currency, 'currency': currency, 'dots': []},
            ],
          });

      expect(build(['Rs', 'Rs']).sharedCurrency, 'Rs');
      expect(build(['Rs', 'AED']).sharedCurrency, isNull);
    });
  });
}
