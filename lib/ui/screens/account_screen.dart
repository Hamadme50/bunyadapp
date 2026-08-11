import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../widgets/fields.dart';
import '../widgets/loading.dart';
import '../widgets/primitives.dart';
import '../widgets/sheet.dart';
import '../widgets/shell.dart';
import '../widgets/toast.dart';

/// Your own account: who you are, how to change your password, and the way out.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _errors = {});

    if (_next.text != _confirm.text) {
      setState(() => _errors = {'confirm': 'Those two do not match.'});
      return;
    }

    setState(() => _busy = true);
    try {
      final session = await ref.read(repositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      ref.read(sessionProvider.notifier).applySession(session);
      _current.clear();
      _next.clear();
      _confirm.clear();
      Toast.success(context, 'Password changed.');
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() => _errors = failure.fields ?? {});
      Toast.error(context, failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const BunyadLoadingPage();

    return Scaffold(
      appBar: const BunyadTopBar(active: NavTab.account),
      body: BunyadPage(
        children: [
          const Eyebrow('Your account', accent: true),
          const SizedBox(height: T.s3),
          Text(user.name, style: T.h1),
          const SizedBox(height: 10),
          Text(user.email, style: T.body.copyWith(fontSize: 15, color: T.ink(0.7))),

          const SizedBox(height: T.s6),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Role',
                  value: user.role.label,
                  valueSize: 18,
                ),
              ),
              const SizedBox(width: T.s2),
              Expanded(
                child: StatTile(
                  label: 'Account created',
                  value: longDateOf(user.createdAt?.toLocal()) ?? '—',
                  valueSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: T.s2),
          StatTile(
            label: 'Last sign-in',
            value: user.lastLoginAt != null ? relative(user.lastLoginAt)! : 'This one',
            valueSize: 18,
          ),

          if (user.isAdmin) ...[
            const SizedBox(height: T.s4),
            Text(
              'As an administrator you issue and manage accounts, and every project on '
              'Bunyad appears on your dashboard. The ones you did not start are yours to '
              'read, not to change.',
              style: T.body.copyWith(fontSize: 12, color: T.ink(0.5)),
            ),
          ],

          const SectionHead(title: 'Change your password'),

          Field(
            label: 'Current password',
            error: _errors['currentPassword'],
            child: BunyadInput(
              controller: _current,
              obscureText: true,
              invalid: _errors.containsKey('currentPassword'),
            ),
          ),
          const SizedBox(height: T.s4),
          Field(
            label: 'New password',
            error: _errors['newPassword'],
            child: BunyadInput(
              controller: _next,
              obscureText: true,
              hintText: 'At least 8 characters',
              invalid: _errors.containsKey('newPassword'),
            ),
          ),
          const SizedBox(height: T.s4),
          Field(
            label: 'Confirm new password',
            error: _errors['confirm'],
            child: BunyadInput(
              controller: _confirm,
              obscureText: true,
              invalid: _errors.containsKey('confirm'),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(height: T.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(label: 'Change password', busy: _busy, onPressed: _save),
          ),

          // The web app signs out from the top bar; on a phone that row has no
          // room, so the way out lives here.
          const SectionHead(title: 'Sign out'),
          Text(
            'This device stays signed in for two years unless you sign out. '
            'Signing out clears the token stored on this phone.',
            style: T.body.copyWith(fontSize: 13, color: T.ink(0.6)),
          ),
          const SizedBox(height: T.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: Btn(
              label: 'Sign out',
              kind: BtnKind.danger,
              icon: Icons.logout_rounded,
              onPressed: _signOut,
            ),
          ),

          const SizedBox(height: T.s8),
          Text(
            'Connected to $kServerUrl',
            style: T.body.copyWith(fontSize: 11, color: T.ink(0.4)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await confirmSheet(
      context,
      title: 'Sign out of Bunyad?',
      body: 'You will need your email and password to sign in again on this phone.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed) return;
    await ref.read(sessionProvider.notifier).signOut();
  }
}
