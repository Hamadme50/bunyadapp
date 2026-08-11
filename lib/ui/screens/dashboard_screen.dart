import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../state/session.dart';
import '../routes.dart';
import '../sheets/project_sheet.dart';
import '../widgets/loading.dart';
import '../widgets/primitives.dart';
import '../widgets/shell.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardView>(
  (ref) => ref.watch(repositoryProvider).dashboard(),
);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _search = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.refresh(dashboardProvider.future);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      // The loader stands in for the whole page, top bar included, so arriving
      // here looks like the splash rather than an empty shell.
      appBar: async.isLoading ? null : const BunyadTopBar(),
      body: async.when(
        loading: () => const BunyadLoadingView(),
        error: (error, _) => ErrorStateView(
          message: error is ApiException ? error.message : '$error',
          onRetry: _refresh,
        ),
        data: (data) => RefreshIndicator(
          color: T.accent,
          onRefresh: _refresh,
          child: _body(data),
        ),
      ),
    );
  }

  Widget _body(DashboardView data) {
    final user = ref.watch(currentUserProvider) ?? data.user;
    final overseeing = data.overseeing;
    final currency = data.sharedCurrency;

    final matching = _matching(data, overseeing);

    return BunyadPage(
      children: [
        Text(todayLong(), style: T.kicker),
        const SizedBox(height: T.s3),
        Text('${greeting()}, ${firstName(user.name)}.', style: T.h1),
        const SizedBox(height: 10),
        Text(
          _summaryLine(data),
          style: T.body.copyWith(fontSize: 15, color: T.ink(0.7)),
        ),

        const SizedBox(height: T.s6),
        _stats(data, currency, overseeing),

        SectionHead(
          title: overseeing ? 'All projects' : 'Your projects',
          topPadding: 44,
          action: Btn(
            label: 'New project',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: _newProject,
          ),
        ),

        if (data.projects.length > 3) ...[
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _filter = value),
            style: T.body.copyWith(fontSize: 14),
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              hintText: overseeing
                  ? 'Search projects, cities, stages, owners…'
                  : 'Search projects, cities, stages…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: T.neutral600),
              suffixIcon: _filter.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: T.neutral600),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() => _filter = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: T.s3),
        ],

        if (data.projects.isEmpty)
          _firstRun()
        else if (matching.isEmpty)
          EmptyState(
            title: 'Nothing matches that.',
            body: overseeing
                ? 'Try part of a project name, the city it is in, or whose project it is.'
                : 'Try part of a project name or the city it is in.',
          )
        else
          ..._rows(matching),

        if (_footnote(data, overseeing) case final String note) ...[
          const SizedBox(height: T.s6),
          Text(note, style: T.body.copyWith(fontSize: 12, color: T.ink(0.5))),
        ],
      ],
    );
  }

  // ── the list ────────────────────────────────────────────────────────────

  List<ProjectCard> _matching(DashboardView data, bool overseeing) {
    final term = _filter.trim().toLowerCase();
    if (term.isEmpty) return data.projects;

    return data.projects.where((project) {
      bool has(String? value) => (value ?? '').toLowerCase().contains(term);
      return has(project.name) ||
          has(project.location) ||
          // Only where the owner's name is on screen to explain the match.
          (overseeing && has(project.ownerName)) ||
          has(project.currentStageName);
    }).toList();
  }

  /// Your own work comes first; say so once, where the list turns over.
  List<Widget> _rows(List<ProjectCard> matching) {
    final rows = <Widget>[];
    var dividerPlaced = false;

    for (final project in matching) {
      if (project.oversight && !dividerPlaced && rows.isNotEmpty) {
        dividerPlaced = true;
        rows.add(const Padding(
          padding: EdgeInsets.only(top: T.s6, bottom: 2),
          child: Eyebrow('Projects you oversee'),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: T.s3),
        child: _ProjectRow(
          project: project,
          onTap: () => context.goProject(project.id),
        ),
      ));
    }
    return rows;
  }

  // ── the strip across the top ────────────────────────────────────────────

  Widget _stats(DashboardView data, String? currency, bool overseeing) {
    final totals = data.totals;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: _spendLabel(currency, overseeing),
                value: currency == null
                    ? number(totals.portfolioTotal)
                    : money(totals.portfolioTotal, currency),
                accent: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: T.s2),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: overseeing ? 'Projects on Bunyad' : 'Projects',
                value: number(totals.projectCount),
                valueSize: 22,
              ),
            ),
            const SizedBox(width: T.s2),
            Expanded(
              child: StatTile(
                label: 'Stages in progress',
                value: number(totals.stagesInProgress),
                valueSize: 22,
              ),
            ),
            const SizedBox(width: T.s2),
            Expanded(
              child: StatTile(
                label: 'Expenses logged',
                value: number(totals.expenseCount),
                valueSize: 22,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Two projects in different money do not add up to one figure with one symbol.
  String _spendLabel(String? currency, bool overseeing) {
    if (currency == null) return 'Total spend, mixed currencies';
    return overseeing ? 'Total spend, every project' : 'Total spend to date';
  }

  String _summaryLine(DashboardView data) {
    final totals = data.totals;
    if (totals.projectCount == 0) {
      return 'No projects yet. Start one and the first stage is ready for its first load of bricks.';
    }

    final overseen = data.projects.where((p) => p.oversight).length;
    // "where the money is going now" is said in the second person, so it may
    // only ever point at a project of your own.
    final active = data.projects.where((p) => p.currentStageName != null && !p.oversight);
    final lead = active.isEmpty ? null : active.first;

    final parts = <String>[
      '${plural(totals.projectCount, 'site')} on the books',
      if (overseen > 0) "${number(overseen)} of them somebody else's",
      if (totals.stagesInProgress > 0) '${plural(totals.stagesInProgress, 'stage')} in progress',
      if (totals.expenseCount > 0) '${plural(totals.expenseCount, 'expense')} logged',
    ];

    final sentence = '${parts.join(', ')}.';
    if (lead == null) return sentence;
    return '$sentence ${lead.currentStageName} at ${lead.location ?? lead.name} '
        'is where the money is going now.';
  }

  /// The note under the list explaining why there is more here than your work.
  String? _footnote(DashboardView data, bool overseeing) {
    if (overseeing) {
      return 'You administer Bunyad, so every project on it appears here. '
          'The ones you did not start are yours to read, not to change.';
    }
    if (data.projects.any((p) => !p.owner)) {
      return 'Projects shared with you appear here too, marked with your access.';
    }
    return null;
  }

  Widget _firstRun() => EmptyState(
        title: 'Nothing on the books yet.',
        body: 'A project starts with the ladder — Plot, Foundations, the grey structure '
            'floor by floor, then the finishing of each. Rename any rung, add your own, '
            'and start logging what each one costs.',
        action: Btn(
          label: 'Start your first project',
          icon: Icons.add_rounded,
          onPressed: _newProject,
        ),
      );

  Future<void> _newProject() async {
    final created = await openProjectSheet(context, ref);
    if (created != null && mounted) {
      context.goProject(created.id);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  One row
// ═══════════════════════════════════════════════════════════════════════════

/// `.project-row`. The web lays this out in three columns; a phone stacks them
/// — identity, progress, then the total — in the same reading order.
class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onTap});

  final ProjectCard project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (project.location != null) Eyebrow(project.location!),
              if (project.plotSizeLabel != null)
                BunyadTag(project.plotSizeLabel!, kind: TagKind.neutral),
              BunyadTag(
                project.accessLabel,
                kind: project.owner || project.access == AccessLevel.editor
                    ? TagKind.accent
                    : TagKind.outline,
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(project.name, style: T.heading(20)),
          const SizedBox(height: T.s2),

          Wrap(
            spacing: 14,
            runSpacing: 2,
            children: [
              // Whose book this is only matters when it is not yours.
              if (project.oversight && project.ownerName != null)
                _meta(project.ownerName!),
              _meta(plural(project.expenseCount, 'expense')),
              _meta(plural(project.memberCount, 'person', 'people')),
              // Not named `when` — that word is a pattern guard keyword.
              if (relative(project.updatedAt) case final String lastTouched)
                _meta('Updated $lastTouched'),
            ],
          ),

          const SizedBox(height: T.s4),
          StageDots(
            states: [
              for (final dot in project.dots)
                switch (dot.status) {
                  StageStatus.complete => 2,
                  StageStatus.inProgress => 1,
                  StageStatus.notStarted => 0,
                },
            ],
          ),
          const SizedBox(height: T.s2),
          Text(_stageLine(project), style: T.body.copyWith(fontSize: 12, color: T.ink(0.6))),

          const SizedBox(height: T.s4),
          const Divider(color: T.hairline, height: 1),
          const SizedBox(height: T.s3),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Eyebrow('Total cost'),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(project.total, project.currency), style: T.amount(22)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 22, color: T.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(String text) =>
      Text(text, style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)));

  String _stageLine(ProjectCard project) {
    if (project.stageCount == 0) return 'No stages yet';
    final done = '${project.completedStages} of ${project.stageCount} stages done';
    return project.currentStageName == null
        ? done
        : '$done · now on ${project.currentStageName}';
  }
}
