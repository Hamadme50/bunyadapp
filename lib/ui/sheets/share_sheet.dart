import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../state/session.dart';
import '../widgets/fields.dart';
import '../widgets/primitives.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';

/// Who can see this project and what they may do. Only the owner opens this;
/// editors add expenses, viewers follow along read-only.
///
/// Returns the project as it stands when the sheet closes.
Future<ProjectView?> openShareSheet(BuildContext context, {required ProjectView project}) {
  return Navigator.of(context, rootNavigator: true).push<ProjectView>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ShareSheet(project: project),
    ),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.project});

  final ProjectView project;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  late ProjectView _project = widget.project;

  final _search = TextEditingController();
  Timer? _debounce;

  List<UserView>? _results;
  bool _searching = false;
  AccessLevel _access = AccessLevel.viewer;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final term = value.trim();
    if (term.length < 2) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _runSearch(term));
  }

  Future<void> _runSearch(String term) async {
    setState(() => _searching = true);
    try {
      final found = await ref.read(repositoryProvider).searchUsers(term);
      final taken = _project.members.map((m) => m.userId).toSet();
      if (mounted) {
        setState(() => _results = found.where((u) => !taken.contains(u.id)).toList());
      }
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addMember(String userId) async {
    try {
      final updated = await ref.read(repositoryProvider).addMember(_project.id, userId, _access);
      if (!mounted) return;
      setState(() {
        _project = updated;
        _results = null;
        _search.clear();
      });
      Toast.success(context, 'Access granted.');
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }

  Future<void> _changeAccess(String userId, AccessLevel access) async {
    try {
      final updated =
          await ref.read(repositoryProvider).changeMemberAccess(_project.id, userId, access);
      if (mounted) setState(() => _project = updated);
    } on ApiException catch (failure) {
      if (mounted) {
        Toast.error(context, failure.message);
        setState(() {});
      }
    }
  }

  Future<void> _removeMember(MemberView member) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Remove ${member.name}?',
      body: '${member.name} will lose access to ${_project.name}. '
          'Expenses they logged stay on the project, still stamped with their name.',
      confirmLabel: 'Remove access',
    );
    if (!confirmed) return;

    try {
      final updated = await ref.read(repositoryProvider).removeMember(_project.id, member.userId);
      if (!mounted) return;
      setState(() => _project = updated);
      Toast.success(context, '${member.name} removed.');
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_project);
      },
      child: BunyadSheetScaffold(
        title: 'Share this project',
        subtitle: _project.name,
        actions: [
          Btn(label: 'Done', onPressed: () => Navigator.of(context).pop(_project)),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'People with access',
              style: TextStyle(fontFamily: T.fontFamily, fontSize: 12, color: T.ink(0.7)),
            ),
            const SizedBox(height: T.s2),

            for (final member in _project.members)
              Padding(
                padding: const EdgeInsets.only(bottom: T.s2),
                child: _MemberRow(
                  member: member,
                  isSelf: member.userId == me?.id,
                  onAccessChanged: (access) => _changeAccess(member.userId, access),
                  onRemove: () => _removeMember(member),
                ),
              ),

            const SizedBox(height: T.s6),
            Text(
              'Add someone',
              style: TextStyle(fontFamily: T.fontFamily, fontSize: 12, color: T.ink(0.7)),
            ),
            const SizedBox(height: T.s2),

            BunyadInput(
              controller: _search,
              hintText: 'Name or email of an existing account',
              textCapitalization: TextCapitalization.none,
              onChanged: _onSearchChanged,
              suffix: _searching
                  ? const Padding(padding: EdgeInsets.all(14), child: Spinner(size: 14))
                  : null,
            ),
            const SizedBox(height: T.s2),
            BunyadSelect<AccessLevel>(
              value: _access,
              items: const [
                (value: AccessLevel.editor, label: 'Editor — can add and edit expenses'),
                (value: AccessLevel.viewer, label: 'Viewer — read only'),
              ],
              onChanged: (value) => setState(() => _access = value ?? AccessLevel.viewer),
            ),

            if (_results != null) ...[
              const SizedBox(height: T.s3),
              if (_results!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(T.s3),
                  decoration: BoxDecoration(
                    color: T.raised,
                    borderRadius: T.brSm,
                    border: Border.all(color: T.hairline),
                  ),
                  child: Text(
                    'No other account matches "${_search.text.trim()}". '
                    'Ask an administrator to create one.',
                    style: T.muted,
                  ),
                )
              else
                for (final user in _results!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: T.s2),
                    child: _ResultRow(user: user, onAdd: () => _addMember(user.id)),
                  ),
            ],

            const SizedBox(height: T.s2),
            Text(
              'Only accounts an administrator has already created can be added.',
              style: T.body.copyWith(fontSize: 12, color: T.ink(0.55)),
            ),
            const SizedBox(height: T.s4),
          ],
        ),
      ),
    );
  }
}

/// `.member-row` — avatar, name and email, then their access.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.onAccessChanged,
    required this.onRemove,
  });

  final MemberView member;
  final bool isSelf;
  final ValueChanged<AccessLevel> onAccessChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: T.s3, vertical: 10),
        decoration: BoxDecoration(
          color: T.raised,
          borderRadius: T.brSm,
          border: Border.all(color: T.hairline),
        ),
        child: Row(
          children: [
            Avatar.md(member.initials),
            const SizedBox(width: T.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${member.name}${isSelf ? ' (you)' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(fontSize: 14, height: 1.3),
                  ),
                  Text(
                    member.email,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(fontSize: 12, color: T.ink(0.55), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: T.s2),
            if (member.owner)
              const BunyadTag('Owner', kind: TagKind.accent)
            else ...[
              SizedBox(
                width: 116,
                child: BunyadSelect<AccessLevel>(
                  value: member.access ?? AccessLevel.viewer,
                  items: const [
                    (value: AccessLevel.editor, label: 'Editor'),
                    (value: AccessLevel.viewer, label: 'Viewer'),
                  ],
                  onChanged: (value) {
                    if (value != null) onAccessChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconBtn(
                icon: Icons.close_rounded,
                tooltip: 'Remove ${member.name}',
                onPressed: onRemove,
                size: 34,
              ),
            ],
          ],
        ),
      );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.user, required this.onAdd});

  final UserView user;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: T.s3, vertical: 10),
        decoration: BoxDecoration(
          color: T.raised,
          borderRadius: T.brSm,
          border: Border.all(color: T.hairline),
        ),
        child: Row(
          children: [
            Avatar.md(user.initials),
            const SizedBox(width: T.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(fontSize: 14, height: 1.3),
                  ),
                  Text(
                    user.email,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(fontSize: 12, color: T.ink(0.55), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: T.s2),
            Btn(label: 'Add', icon: Icons.add_rounded, compact: true, onPressed: onAdd),
          ],
        ),
      );
}
