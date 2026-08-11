import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../state/session.dart';
import '../routes.dart';
import '../sheets/project_sheet.dart';
import '../sheets/share_sheet.dart';
import '../sheets/stage_sheet.dart';
import '../widgets/loading.dart';
import '../widgets/primitives.dart';
import '../widgets/sheet.dart';
import '../widgets/shell.dart';
import '../widgets/toast.dart';

final projectProvider = FutureProvider.autoDispose.family<ProjectView, String>(
  (ref, projectId) => ref.watch(repositoryProvider).project(projectId),
);

class ProjectScreen extends ConsumerStatefulWidget {
  const ProjectScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  /// Most mutations answer with the whole project, so the screen can repaint
  /// from the response instead of asking again.
  ProjectView? _override;

  ProjectView? get _current => _override;

  void _apply(ProjectView? project) {
    if (project != null) setState(() => _override = project);
  }

  Future<void> _reload() async {
    setState(() => _override = null);
    ref.invalidate(projectProvider(widget.projectId));
    await ref.read(projectProvider(widget.projectId).future);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectProvider(widget.projectId));
    final project = _current ?? async.valueOrNull;

    // Nothing to show yet and nothing gone wrong: the loader takes the page.
    final loading = project == null && async.isLoading;

    return Scaffold(
      appBar: loading ? null : const BunyadTopBar(),
      body: project != null
          ? RefreshIndicator(
              color: T.accent,
              onRefresh: _reload,
              child: _body(project),
            )
          : async.when(
              loading: () => const BunyadLoadingView(),
              error: (error, _) => ErrorStateView(
                message: error is ApiException ? error.message : '$error',
                gone: error is ApiException && (error.status == 404 || error.status == 403),
                onRetry: _reload,
                onBack: () => context.goDashboard(),
              ),
              data: (data) => _body(data),
            ),
    );
  }

  Widget _body(ProjectView project) {
    final canEdit = project.canEdit;

    return Column(
      children: [
        ViewerNotice(
          isViewer: project.access == AccessLevel.viewer,
          oversight: project.oversight,
        ),
        Expanded(
          child: BunyadPage(
            children: [
              BackLink(label: 'All projects', onTap: () => context.goDashboard()),
              const SizedBox(height: T.s3),

              _header(project, canEdit),
              const SizedBox(height: T.s3),
              _teamStrip(project),

              SectionHead(
                title: 'Stages',
                note: canEdit
                    ? 'Rename or remove any stage — this ladder is yours.'
                    : 'Open a stage to follow its expenses.',
                topPadding: 40,
              ),

              ..._stageCells(project, canEdit),

              if (project.materials.isNotEmpty) ..._materials(project),
              if (canEdit) ..._heads(project),
            ],
          ),
        ),
      ],
    );
  }

  // ── header ──────────────────────────────────────────────────────────────

  Widget _header(ProjectView project, bool canEdit) {
    final kicker = [
      project.location,
      if (longDate(project.startedOn) case final String started) 'Started $started',
    ].whereType<String>().join(' · ');

    return Container(
      padding: const EdgeInsets.all(T.s4),
      decoration: BoxDecoration(
        color: T.raised,
        borderRadius: T.brLg,
        border: Border.all(color: T.hairline),
        boxShadow: T.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kicker.isNotEmpty) ...[
            Text(kicker, style: T.kicker),
            const SizedBox(height: T.s2),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(project.name, style: T.h1)),
              if (canEdit) ...[
                const SizedBox(width: T.s2),
                IconBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Project details',
                  onPressed: () async {
                    _apply(await openProjectSheet(context, ref, project: project));
                  },
                ),
              ],
              if (project.canAdminister) ...[
                const SizedBox(width: 6),
                IconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete project',
                  color: T.accent700,
                  onPressed: () => _deleteProject(project),
                ),
              ],
            ],
          ),

          const SizedBox(height: T.s2),
          Wrap(
            spacing: T.s2,
            runSpacing: T.s2,
            children: [
              if (project.plotSizeLabel != null)
                BunyadTag(project.plotSizeLabel!, kind: TagKind.accent),
              if (!project.canAdminister) BunyadTag(project.accessLabel, kind: TagKind.outline),
            ],
          ),

          const SizedBox(height: T.s6),
          const Eyebrow('Project total cost'),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(project.total, project.currency), style: T.amount(38, color: T.accent)),
          ),
          const SizedBox(height: T.s2),
          Text(
            'Across ${plural(project.stages.length, 'stage')} · '
            '${plural(project.expenseCount, 'expense')}',
            style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProject(ProjectView project) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Delete ${project.name}?',
      body: 'Every stage, all ${number(project.expenseCount)} expenses and their photos go '
          'with it. This cannot be undone.',
      confirmLabel: 'Delete the project',
    );
    if (!confirmed) return;

    try {
      await ref.read(repositoryProvider).deleteProject(project.id);
      if (!mounted) return;
      Toast.success(context, '${project.name} deleted.');
      context.goDashboard();
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }

  // ── team ────────────────────────────────────────────────────────────────

  Widget _teamStrip(ProjectView project) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Eyebrow('Team'),
          const SizedBox(height: T.s3),
          Wrap(
            spacing: 20,
            runSpacing: T.s3,
            children: [
              for (final member in project.members)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar.md(member.initials),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(member.name, style: T.body.copyWith(fontSize: 13, height: 1.25)),
                        Text(
                          member.accessLabel,
                          style: T.body.copyWith(fontSize: 11, color: T.ink(0.55), height: 1.25),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: T.s3),
          if (project.canAdminister)
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                label: 'Share project',
                kind: BtnKind.secondary,
                icon: Icons.person_add_alt_1_outlined,
                compact: true,
                onPressed: () async {
                  _apply(await openShareSheet(context, project: project));
                },
              ),
            )
          // Nothing to leave when you are only here as the administrator.
          else if (!project.oversight)
            Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                label: 'Leave project',
                kind: BtnKind.ghost,
                onPressed: () => _leaveProject(project),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _leaveProject(ProjectView project) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Leave ${project.name}?',
      body: 'You will lose access until the owner shares it with you again.',
      confirmLabel: 'Leave',
    );
    if (!confirmed) return;

    try {
      await ref.read(repositoryProvider).leaveProject(project.id);
      if (!mounted) return;
      Toast.success(context, 'You left ${project.name}.');
      context.goDashboard();
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }

  // ── stages ──────────────────────────────────────────────────────────────

  List<Widget> _stageCells(ProjectView project, bool canEdit) {
    return [
      for (var i = 0; i < project.stages.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: T.s3),
          child: _StageCell(
            project: project,
            stage: project.stages[i],
            index: i,
            canEdit: canEdit,
            onOpen: () => context.goStage(project.id, project.stages[i].id),
            onEdit: () async {
              _apply(await openStageSheet(context, projectId: project.id, stage: project.stages[i]));
            },
            onDelete: () => _deleteStage(project, project.stages[i]),
          ),
        ),
      if (canEdit)
        InkWell(
          onTap: () async {
            _apply(await openStageSheet(context, projectId: project.id));
          },
          borderRadius: T.brCard,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: T.raised.withValues(alpha: 0.55),
              borderRadius: T.brCard,
              border: Border.all(color: T.hairlineStrong, style: BorderStyle.solid),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 22, color: T.accent),
                const SizedBox(height: 10),
                Text('Add a stage', style: T.heading(16)),
                const SizedBox(height: 4),
                Text(
                  'Roof, plaster, finishing, boundary wall — whatever this build needs.',
                  style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _deleteStage(ProjectView project, StageCard stage) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Delete ${stage.name}?',
      body: stage.expenseCount > 0
          ? '${plural(stage.expenseCount, 'expense')} filed on this stage and their photos '
              'will be deleted too. This cannot be undone.'
          : 'This stage has no expenses on it yet.',
      confirmLabel: 'Delete the stage',
    );
    if (!confirmed) return;

    try {
      _apply(await ref.read(repositoryProvider).deleteStage(project.id, stage.id));
      if (mounted) Toast.success(context, '${stage.name} removed.');
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }

  // ── where the money went ────────────────────────────────────────────────

  List<Widget> _materials(ProjectView project) {
    return [
      const SectionHead(
        title: 'Where the money went',
        note: 'Materials and labour from the build stages — plot and land costs excluded',
      ),
      for (final row in project.materials)
        Padding(
          padding: const EdgeInsets.only(bottom: T.s2),
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(row.head, style: T.heading(15))),
                    const SizedBox(width: T.s2),
                    Text(money(row.total, project.currency), style: T.amount(16)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  row.quantitySummary ?? _weightLabel(row) ?? '—',
                  style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
                ),
                const SizedBox(height: T.s2),
                Row(
                  children: [
                    Expanded(child: Meter(percent: row.sharePercent, height: 8)),
                    const SizedBox(width: T.s3),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${row.sharePercent}%',
                        textAlign: TextAlign.right,
                        style: T.body.copyWith(fontSize: 12, color: T.ink(0.65)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  String? _weightLabel(MaterialRow row) {
    final kg = (row.weightKg ?? 0).toDouble();
    if (kg == 0) return null;
    return kg >= 1000 ? '${number((kg / 100).round() / 10)} ton' : '${number(kg)} kg';
  }

  // ── expense heads ───────────────────────────────────────────────────────

  List<Widget> _heads(ProjectView project) {
    return [
      const SectionHead(
        title: 'Expense heads',
        note: 'What the form suggests. Plot-kind stages get the plot list, everything else '
            'the materials.',
      ),
      Wrap(
        spacing: T.s2,
        runSpacing: T.s2,
        children: [
          for (final head in project.heads)
            BunyadChip(
              label: head.name,
              neutral: head.scope != HeadScope.plot,
              // Heads with expenses filed under them cannot be removed.
              onRemove: head.inUse ? null : () => _removeHead(project, head),
              removeTooltip: 'Remove ${head.name}',
            ),
          BunyadChip(
            label: 'Add your own head',
            icon: Icons.add_rounded,
            onTap: () => _addHead(project),
          ),
        ],
      ),
    ];
  }

  Future<void> _addHead(ProjectView project) async {
    final name = await promptForText(
      context,
      title: 'Add an expense head',
      body: 'It is suggested on every stage of this project.',
      hintText: 'e.g. Waterproofing, Electrical',
      confirmLabel: 'Add head',
    );
    if (name == null || name.isEmpty) return;

    try {
      _apply(await ref.read(repositoryProvider).addHead(project.id, name));
      if (mounted) Toast.success(context, '"$name" is now suggested on every stage.');
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }

  Future<void> _removeHead(ProjectView project, HeadView head) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Remove "${head.name}"?',
      body: 'It disappears from the suggestion chips. Expenses already filed under it are '
          'untouched.',
      confirmLabel: 'Remove head',
    );
    if (!confirmed) return;

    try {
      _apply(await ref.read(repositoryProvider).deleteHead(project.id, head.id));
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  One stage
// ═══════════════════════════════════════════════════════════════════════════

/// `.stage-cell` — its number, name, dates, status, total and share.
class _StageCell extends StatelessWidget {
  const _StageCell({
    required this.project,
    required this.stage,
    required this.index,
    required this.canEdit,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectView project;
  final StageCard stage;
  final int index;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onOpen,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: T.neutral100, borderRadius: T.brXs),
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: T.fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.08 * 11,
                    color: T.neutral700,
                  ),
                ),
              ),
              const SizedBox(width: T.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(stage.name, style: T.heading(19)),
                    const SizedBox(height: 5),
                    Text(
                      stageDates(
                        startedOn: stage.startedOn,
                        completedOn: stage.completedOn,
                        plannedNote: stage.plannedNote,
                      ),
                      style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: T.s2),
              BunyadTag.status(
                stage.statusLabel,
                inProgress: stage.status == StageStatus.inProgress,
                complete: stage.status == StageStatus.complete,
              ),
            ],
          ),

          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(stage.total, project.currency), style: T.amount(24)),
          ),
          const SizedBox(height: 6),
          Text(
            '${plural(stage.expenseCount, 'expense')} · ${stage.sharePercent}% of project',
            style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
          ),
          const SizedBox(height: 10),
          Meter(percent: stage.sharePercent),

          if (canEdit) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                IconBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Rename ${stage.name}',
                  onPressed: onEdit,
                  size: 34,
                ),
                const SizedBox(width: 6),
                IconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete ${stage.name}',
                  color: T.accent700,
                  onPressed: onDelete,
                  size: 34,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
