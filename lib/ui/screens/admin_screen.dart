import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../state/session.dart';
import '../widgets/fields.dart';
import '../widgets/loading.dart';
import '../widgets/primitives.dart';
import '../widgets/sheet.dart';
import '../widgets/shell.dart';
import '../widgets/toast.dart';

final usersProvider = FutureProvider.autoDispose<List<UserView>>(
  (ref) => ref.watch(repositoryProvider).users(),
);

/// Account administration. Only an ADMIN can reach this route.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(usersProvider);
    Future<void> reload() => ref.refresh(usersProvider.future);

    return Scaffold(
      appBar: async.isLoading ? null : const BunyadTopBar(active: NavTab.people),
      body: async.when(
        loading: () => const BunyadLoadingView(),
        error: (error, _) => ErrorStateView(
          message: error is ApiException ? error.message : '$error',
          onRetry: reload,
        ),
        data: (users) {
          final admins = users.where((u) => u.role == Role.admin && u.active).length;

          return RefreshIndicator(
            color: T.accent,
            onRefresh: reload,
            child: BunyadPage(
              children: [
                const Eyebrow('Administration', accent: true),
                const SizedBox(height: T.s3),
                Text('People', style: T.h1),
                const SizedBox(height: 10),
                Text(
                  'Everyone who can sign in. Nobody registers themselves — you issue the '
                  'account and hand over the first password.',
                  style: T.body.copyWith(fontSize: 15, color: T.ink(0.7)),
                ),

                SectionHead(
                  title: '${users.length} account${users.length == 1 ? '' : 's'}',
                  note: '$admins administrator${admins == 1 ? '' : 's'}',
                  topPadding: 36,
                  action: Btn(
                    label: 'New user',
                    icon: Icons.add_rounded,
                    compact: true,
                    onPressed: () async {
                      final created = await _openUserSheet(context, ref);
                      if (created) await reload();
                    },
                  ),
                ),

                for (final user in users)
                  Padding(
                    padding: const EdgeInsets.only(bottom: T.s2),
                    child: _UserRow(user: user, onChanged: reload),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user, required this.onChanged});

  final UserView user;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelf = user.id == ref.watch(currentUserProvider)?.id;

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar.md(user.initials),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user.name}${isSelf ? ' (you)' : ''}',
                      style: T.heading(15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: T.s2),
              BunyadTag(
                user.role == Role.admin ? 'Admin' : 'User',
                kind: user.role == Role.admin ? TagKind.accent : TagKind.neutral,
              ),
            ],
          ),

          const SizedBox(height: T.s3),
          Wrap(
            spacing: T.s2,
            runSpacing: T.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!user.active)
                const BunyadTag('Deactivated', kind: TagKind.outline)
              else if (user.mustChangePassword)
                const BunyadTag('Password pending', kind: TagKind.outline)
              else
                Text('Active', style: T.body.copyWith(fontSize: 12, color: T.ink(0.6))),
              Text(
                user.lastLoginAt != null
                    ? 'Last sign-in ${relative(user.lastLoginAt)}'
                    : 'Never signed in',
                style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
              ),
              if (longDateOf(user.createdAt?.toLocal()) case final String added)
                Text('Added $added', style: T.body.copyWith(fontSize: 12, color: T.ink(0.6))),
            ],
          ),

          const SizedBox(height: T.s3),
          Row(
            children: [
              IconBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Edit ${user.name}',
                size: 34,
                onPressed: () async {
                  final saved = await _openUserSheet(context, ref, user: user);
                  if (saved) await onChanged();
                },
              ),
              const SizedBox(width: 6),
              IconBtn(
                icon: Icons.key_outlined,
                tooltip: 'Reset password for ${user.name}',
                size: 34,
                onPressed: () => _resetPassword(context, ref, user),
              ),
              if (!isSelf) ...[
                const SizedBox(width: 6),
                IconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete ${user.name}',
                  color: T.accent700,
                  size: 34,
                  onPressed: () => _deleteUser(context, ref, user, onChanged),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _resetPassword(BuildContext context, WidgetRef ref, UserView user) async {
  final confirmed = await confirmSheet(
    context,
    title: 'Reset the password for ${user.name}?',
    body: 'A new password is generated and shown once. They will have to change it at '
        'next sign-in.',
    confirmLabel: 'Reset password',
    danger: false,
  );
  if (!confirmed) return;

  try {
    final result = await ref.read(repositoryProvider).resetPassword(user.id);
    if (context.mounted) {
      await showCredential(context, email: user.email, name: user.name, password: result.password);
    }
  } on ApiException catch (failure) {
    if (context.mounted) Toast.error(context, failure.message);
  }
}

Future<void> _deleteUser(
  BuildContext context,
  WidgetRef ref,
  UserView user,
  Future<void> Function() onChanged,
) async {
  final confirmed = await confirmSheet(
    context,
    title: 'Delete ${user.name}?',
    body: 'Accounts that still own projects cannot be deleted — deactivate them instead, '
        'which keeps their history intact but blocks sign-in.',
    confirmLabel: 'Delete account',
  );
  if (!confirmed) return;

  try {
    await ref.read(repositoryProvider).deleteUser(user.id);
    if (context.mounted) Toast.success(context, '${user.name} deleted.');
    await onChanged();
  } on ApiException catch (failure) {
    if (context.mounted) Toast.error(context, failure.message);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Create / edit
// ═══════════════════════════════════════════════════════════════════════════

Future<bool> _openUserSheet(BuildContext context, WidgetRef ref, {UserView? user}) async {
  final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _UserSheet(user: user),
    ),
  );
  return saved ?? false;
}

class _UserSheet extends ConsumerStatefulWidget {
  const _UserSheet({this.user});

  final UserView? user;

  @override
  ConsumerState<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends ConsumerState<_UserSheet> {
  late final bool _editing = widget.user != null;

  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  late final _password = TextEditingController();

  late Role _role = widget.user?.role ?? Role.user;
  late bool _active = widget.user?.active ?? true;

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errors = {};
    });

    final repo = ref.read(repositoryProvider);

    try {
      if (_editing) {
        await repo.updateUser(
          widget.user!.id,
          name: _name.text.trim(),
          role: _role,
          active: _active,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        Toast.success(context, 'Account updated.');
      } else {
        final issued = await repo.createUser(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text.trim().isEmpty ? null : _password.text.trim(),
          role: _role,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        await showCredential(
          context,
          email: issued.user?.email ?? _email.text.trim(),
          name: issued.user?.name ?? _name.text.trim(),
          password: issued.password,
        );
      }
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
    return BunyadSheetScaffold(
      title: _editing ? 'Edit account' : 'New account',
      subtitle: _editing ? widget.user!.email : 'Administration',
      actions: [
        Btn(
          label: 'Cancel',
          kind: BtnKind.secondary,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        Btn(
          label: _editing ? 'Save changes' : 'Create account',
          busy: _busy,
          onPressed: _save,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: 'Full name',
            error: _errors['name'],
            child: BunyadInput(
              controller: _name,
              hintText: 'Bilal Ahmed',
              maxLength: 120,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.words,
              invalid: _errors.containsKey('name'),
            ),
          ),
          const SizedBox(height: 18),

          Field(
            label: 'Email',
            error: _errors['email'],
            child: BunyadInput(
              controller: _email,
              hintText: 'bilal@example.com',
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              // An account's email is its identity; it cannot be changed later.
              enabled: !_editing,
              invalid: _errors.containsKey('email'),
            ),
          ),
          const SizedBox(height: 18),

          Field(
            label: 'Role',
            error: _errors['role'],
            child: BunyadSelect<Role>(
              value: _role,
              items: const [
                (value: Role.user, label: 'User — creates and shares projects'),
                (value: Role.admin, label: 'Administrator — also manages accounts'),
              ],
              onChanged: (value) => setState(() => _role = value ?? Role.user),
            ),
          ),
          const SizedBox(height: 18),

          if (_editing)
            Field(
              label: 'Status',
              child: BunyadSelect<bool>(
                value: _active,
                items: const [
                  (value: true, label: 'Active'),
                  (value: false, label: 'Deactivated — cannot sign in'),
                ],
                onChanged: (value) => setState(() => _active = value ?? true),
              ),
            )
          else ...[
            Field(
              label: 'First password',
              error: _errors['password'],
              child: BunyadInput(
                controller: _password,
                hintText: 'Leave blank to generate one',
                textCapitalization: TextCapitalization.none,
                invalid: _errors.containsKey('password'),
              ),
            ),
            const SizedBox(height: T.s3),
            Text(
              'They will be asked to choose their own password the first time they sign in.',
              style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
            ),
          ],
          const SizedBox(height: T.s4),
        ],
      ),
    );
  }
}

/// The password is shown exactly once — there is no way to read it back.
Future<void> showCredential(
  BuildContext context, {
  required String email,
  required String name,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: T.neutral900.withValues(alpha: 0.42),
    builder: (context) => Dialog(
      backgroundColor: T.bg,
      insetPadding: const EdgeInsets.all(T.s4),
      shape: RoundedRectangleBorder(borderRadius: T.brLg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: T.raised,
            padding: const EdgeInsets.all(T.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hand this over', style: T.heading(20)),
                const SizedBox(height: 4),
                Text(email, style: T.body.copyWith(fontSize: 13, color: T.ink(0.55))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(T.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$name can sign in with this password. It is shown once and cannot be '
                  'read again — reset it if it gets lost.',
                  style: T.body.copyWith(fontSize: 14),
                ),
                const SizedBox(height: T.s4),
                // `.credential` — monospaced, wide-tracked, selectable.
                Container(
                  padding: const EdgeInsets.all(T.s4),
                  decoration: BoxDecoration(
                    color: T.surface,
                    borderRadius: T.brSm,
                    border: const Border(left: BorderSide(color: T.accent, width: 3)),
                  ),
                  child: SelectableText(
                    password,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      letterSpacing: 0.06 * 16,
                      color: T.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: T.raised,
            padding: const EdgeInsets.all(T.s3),
            child: Row(
              children: [
                Btn(
                  label: 'Copy password',
                  kind: BtnKind.secondary,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: password));
                    if (context.mounted) Toast.success(context, 'Password copied.');
                  },
                ),
                const Spacer(),
                Btn(label: 'Done', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
