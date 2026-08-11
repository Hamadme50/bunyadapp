import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../state/session.dart';
import '../widgets/fields.dart';
import '../widgets/primitives.dart';
import '../widgets/toast.dart';
import 'login_screen.dart';

/// Shown when an administrator has issued or reset a password — the account
/// cannot be used until a new one is set.
class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_next.text != _confirm.text) {
      setState(() => _error = 'Those two do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Someone on a forced reset does not know the old password by definition,
      // so none is sent.
      final session = await ref
          .read(repositoryProvider)
          .changePassword(newPassword: _next.text);
      if (!mounted) return;
      ref.read(sessionProvider.notifier).applySession(session);
      Toast.success(context, 'Password set. Welcome to Bunyad.');
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email ?? 'your account';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(T.s3),
          children: [
            LoginPoster(
              title: 'One thing first.',
              body: 'The password on $email was issued by an administrator. '
                  'Set your own before you go on.',
            ),
            const SizedBox(height: T.s3),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s8),
              decoration: BoxDecoration(
                color: T.raised,
                borderRadius: T.brLg,
                border: Border.all(color: T.hairline),
                boxShadow: T.shadowMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Eyebrow('Choose a password', accent: true),
                  const SizedBox(height: T.s2),
                  Text('Make it yours', style: T.h2),

                  if (_error != null) ...[
                    const SizedBox(height: T.s4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: T.s3, vertical: 11),
                      decoration: BoxDecoration(
                        color: T.accent100,
                        borderRadius: T.brSm,
                        border: Border.all(color: T.accent.withValues(alpha: 0.28)),
                      ),
                      child: Text(_error!, style: T.bodySm),
                    ),
                  ],

                  const SizedBox(height: T.s4),
                  Field(
                    label: 'New password',
                    child: BunyadInput(
                      controller: _next,
                      obscureText: true,
                      hintText: 'At least 8 characters',
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: T.s4),
                  Field(
                    label: 'Confirm password',
                    child: BunyadInput(
                      controller: _confirm,
                      obscureText: true,
                      hintText: 'Type it again',
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),

                  const SizedBox(height: T.s4),
                  Btn(label: 'Set password', block: true, busy: _busy, onPressed: _submit),

                  const SizedBox(height: T.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Btn(
                      label: 'Sign out instead',
                      kind: BtnKind.ghost,
                      icon: Icons.logout_rounded,
                      onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
