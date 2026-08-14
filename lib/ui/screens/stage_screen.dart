import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../routes.dart';
import '../sheets/expense_sheet.dart';
import '../sheets/stage_sheet.dart';
import '../widgets/photos.dart';
import '../widgets/loading.dart';
import '../widgets/primitives.dart';
import '../widgets/sheet.dart';
import '../widgets/shell.dart';
import '../widgets/toast.dart';

/// One stage and its expense timeline, newest first.
class StageScreen extends ConsumerStatefulWidget {
  const StageScreen({super.key, required this.projectId, required this.stageId});

  final String projectId;
  final String stageId;

  @override
  ConsumerState<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends ConsumerState<StageScreen> {
  StageView? _data;
  Object? _error;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await ref.read(repositoryProvider).stage(
            widget.projectId,
            widget.stageId,
            limit: kPageSize,
          );
      if (mounted) setState(() => _data = data);
    } catch (failure) {
      if (mounted) setState(() => _error = failure);
    }
  }

  /// After a save, re-read everything already on screen so the totals and the
  /// edited row both refresh.
  Future<void> _reload() async {
    final shown = _data?.expenses.length ?? kPageSize;
    try {
      final data = await ref.read(repositoryProvider).stage(
            widget.projectId,
            widget.stageId,
            limit: shown < kPageSize ? kPageSize : shown,
          );
      if (mounted) setState(() => _data = data);
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }

  Future<void> _loadMore() async {
    final data = _data;
    if (data == null || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(repositoryProvider).stage(
            widget.projectId,
            widget.stageId,
            offset: data.expenses.length,
            limit: kPageSize,
          );
      if (mounted) {
        setState(() => _data = next.withExpenses(
              [...data.expenses, ...next.expenses],
              next.hasMore,
            ));
      }
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _addExpense([String? presetHead]) async {
    final data = _data;
    if (data == null) return;

    final saved = await openExpenseSheet(
      context,
      projectId: widget.projectId,
      stage: data.stage,
      projectName: data.projectName,
      currency: data.currency,
      suggestions: data.suggestions,
      presetHead: presetHead,
    );
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    final loading = data == null && _error == null;

    return Scaffold(
      appBar: loading ? null : const BunyadTopBar(),
      floatingActionButton: data != null && data.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _addExpense(),
              backgroundColor: T.accent,
              foregroundColor: T.bg,
              icon: const Icon(Icons.add_rounded),
              label: Text('Add expense', style: T.heading(14, color: T.bg)),
            )
          : null,
      body: switch ((data, _error)) {
        (final StageView view, _) => RefreshIndicator(
            color: T.accent,
            onRefresh: _reload,
            child: _body(view),
          ),
        (null, final Object error) => ErrorStateView(
            message: error is ApiException ? error.message : '$error',
            gone: error is ApiException && (error.status == 404 || error.status == 403),
            onRetry: _load,
            onBack: () => context.goDashboard(),
          ),
        _ => const BunyadLoadingView(),
      },
    );
  }

  Widget _body(StageView data) {
    final stage = data.stage;

    return Column(
      children: [
        ViewerNotice(
          isViewer: data.access == AccessLevel.viewer,
          oversight: data.oversight,
        ),
        Expanded(
          child: BunyadPage(
            children: [
              BackLink(
                label: data.projectName,
                onTap: () => context.goBack(Routes.project(widget.projectId)),
              ),
              const SizedBox(height: T.s3),

              _header(data),

              const SizedBox(height: T.s6),
              Text('Expense timeline', style: T.heading(19)),
              const SizedBox(height: 3),
              Text(
                data.expenses.isEmpty
                    ? 'No expenses yet'
                    : 'Showing ${number(data.expenses.length)} of '
                        '${number(stage.expenseCount)} · newest first',
                style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
              ),
              const SizedBox(height: T.s3),

              if (data.expenses.isEmpty)
                _emptyState(data)
              else
                for (final expense in data.expenses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: T.s3),
                    child: _ExpenseRow(
                      expense: expense,
                      currency: data.currency,
                      onEdit: () => _editExpense(data, expense),
                      onDelete: () => _deleteExpense(expense),
                    ),
                  ),

              if (data.hasMore) ...[
                const SizedBox(height: T.s3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                    label: 'Load older expenses',
                    kind: BtnKind.secondary,
                    busy: _loadingMore,
                    busyLabel: 'Loading…',
                    onPressed: _loadMore,
                  ),
                ),
              ],

              if (data.canEdit && data.suggestions.isNotEmpty) ...[
                const SizedBox(height: T.s6),
                Container(
                  padding: const EdgeInsets.all(T.s4),
                  decoration: BoxDecoration(
                    color: T.surface.withValues(alpha: 0.55),
                    borderRadius: T.brCard,
                    border: Border.all(color: T.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Eyebrow('Suggested for this stage — tap to start an expense'),
                      const SizedBox(height: T.s3),
                      Wrap(
                        spacing: T.s2,
                        runSpacing: T.s2,
                        children: [
                          for (final suggestion in data.suggestions)
                            BunyadChip(
                              label: suggestion,
                              onTap: () => _addExpense(suggestion),
                            ),
                          BunyadChip(
                            label: 'Add your own name',
                            icon: Icons.add_rounded,
                            neutral: true,
                            onTap: () => _addExpense(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Room for the floating button not to cover the last row.
              const SizedBox(height: 64),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(StageView data) {
    final stage = data.stage;

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
          Row(
            children: [
              Text(
                'Stage ${(stage.position + 1).toString().padLeft(2, '0')}',
                style: T.kicker,
              ),
              const SizedBox(width: T.s3),
              BunyadTag.status(
                stage.statusLabel,
                inProgress: stage.status == StageStatus.inProgress,
                complete: stage.status == StageStatus.complete,
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(stage.name, style: T.h1)),
              if (data.canEdit) ...[
                const SizedBox(width: T.s2),
                IconBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Stage details',
                  onPressed: () async {
                    final updated =
                        await openStageSheet(context, projectId: widget.projectId, stage: stage);
                    if (updated != null) await _reload();
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),
          Text(
            stageDates(
              startedOn: stage.startedOn,
              completedOn: stage.completedOn,
              plannedNote: stage.plannedNote,
            ),
            style: T.body.copyWith(fontSize: 13, color: T.ink(0.65)),
          ),

          const SizedBox(height: T.s6),
          const Eyebrow('Stage total'),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(stage.total, data.currency), style: T.amount(38, color: T.accent)),
          ),
          const SizedBox(height: T.s2),
          Text(
            '${plural(stage.expenseCount, 'expense')} · '
            '${stage.sharePercent}% of project total',
            style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(StageView data) => EmptyState(
        title: 'Nothing logged here yet.',
        body: data.canEdit
            ? "Work hasn't started on ${data.stage.name}. When the first truck arrives, "
                'log it here and the stage total starts counting itself.'
            : 'Nothing has been filed against ${data.stage.name} yet.',
        action: data.canEdit
            ? Btn(
                label: 'Log the first expense',
                icon: Icons.add_rounded,
                onPressed: () => _addExpense(),
              )
            : null,
      );

  Future<void> _editExpense(StageView data, ExpenseView expense) async {
    final saved = await openExpenseSheet(
      context,
      projectId: widget.projectId,
      stage: data.stage,
      projectName: data.projectName,
      currency: data.currency,
      suggestions: data.suggestions,
      expense: expense,
    );
    if (saved == true) await _reload();
  }

  Future<void> _deleteExpense(ExpenseView expense) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Delete "${expense.name}"?',
      body: expense.files.isNotEmpty
          ? 'Its ${plural(expense.files.length, 'photo')} will be deleted too. '
              'This cannot be undone.'
          : 'This cannot be undone.',
      confirmLabel: 'Delete expense',
    );
    if (!confirmed) return;

    try {
      await ref.read(repositoryProvider).deleteExpense(expense.id);
      if (!mounted) return;
      Toast.success(context, 'Expense deleted.');
      await _reload();
    } on ApiException catch (failure) {
      if (mounted) Toast.error(context, failure.message);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  One timeline entry
// ═══════════════════════════════════════════════════════════════════════════

/// `.expense-row` — the date block, what was bought, and what it cost.
/// "3 photos", "1 PDF", or "2 photos · 1 PDF" — whichever the strip holds.
String _attachmentSummary(List<FileView> files) {
  final pdfs = files.where((f) => f.isPdf).length;
  final images = files.length - pdfs;
  final parts = [
    if (images > 0) plural(images, 'photo'),
    if (pdfs > 0) '$pdfs PDF',
  ];
  return parts.join(' · ');
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({
    required this.expense,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseView expense;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = dayParts(expense.expenseDate);
    final photos = expense.files;

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // `.expense-date` — the stacked day over month.
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: T.neutral100, borderRadius: T.brSm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(parts.day, style: T.amount(22)),
                    const SizedBox(height: 4),
                    Text(
                      parts.month.toUpperCase(),
                      style: T.eyebrow.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: T.s3),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(expense.name, style: T.heading(17)),
                    const SizedBox(height: 6),
                    BunyadTag(expense.head, kind: TagKind.neutral),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: T.s3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(expense.amount, currency), style: T.amount(22)),
          ),

          if (_facts.isNotEmpty) ...[
            const SizedBox(height: T.s3),
            Wrap(
              spacing: 24,
              runSpacing: T.s2,
              children: [
                for (final fact in _facts)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fact.$1.toUpperCase(), style: T.eyebrow.copyWith(fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(fact.$2, style: T.bodySm),
                    ],
                  ),
              ],
            ),
          ],

          if (expense.notes != null) ...[
            const SizedBox(height: T.s3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: T.s3, vertical: 8),
              decoration: BoxDecoration(
                color: T.neutral100,
                borderRadius: T.brSm,
                border: const Border(left: BorderSide(color: T.neutral300, width: 3)),
              ),
              child: Text(
                expense.notes!,
                style: T.body.copyWith(fontSize: 13, color: T.ink(0.75)),
              ),
            ),
          ],

          if (photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Only the images go in the lightbox, and the indexes have to
                // be indexes into that list — a PDF sitting in the middle of
                // the strip would otherwise open the wrong photo.
                for (final file in photos)
                  if (file.isPdf)
                    PdfThumb(
                      filename: file.filename,
                      onTap: () => openStoredPdf(context, ref, file),
                    )
                  else
                    PhotoThumb(
                      fileId: file.id,
                      onTap: () => openLightbox(
                        context,
                        [
                          for (final image in photos.where((f) => !f.isPdf))
                            LightboxPhoto(
                              fileId: image.id,
                              caption: '${expense.name} — ${image.filename}',
                            ),
                        ],
                        photos.where((f) => !f.isPdf).toList().indexOf(file),
                      ),
                    ),
                Text(
                  _attachmentSummary(photos),
                  style: T.body.copyWith(fontSize: 11, color: T.ink(0.5)),
                ),
              ],
            ),
          ],

          const SizedBox(height: T.s3),
          Row(
            children: [
              Avatar(expense.createdByInitials ?? '?'),
              const SizedBox(width: T.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Added by ${firstName(expense.createdByName)}',
                      style: T.body.copyWith(fontSize: 11, color: T.ink(0.6)),
                    ),
                    if (expense.updatedByName != null)
                      Text(
                        'Edited by ${firstName(expense.updatedByName)}',
                        style: T.body.copyWith(fontSize: 11, color: T.ink(0.5)),
                      ),
                  ],
                ),
              ),
              if (expense.canEdit) ...[
                IconBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit this expense',
                  onPressed: onEdit,
                  size: 34,
                ),
                const SizedBox(width: 6),
                IconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete this expense',
                  color: T.accent700,
                  onPressed: onDelete,
                  size: 34,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The labelled facts, skipping whatever was left blank.
  List<(String, String)> get _facts => [
        if (expense.quantityLabel != null) ('Quantity', expense.quantityLabel!),
        if (expense.weightLabel != null) ('Weight', expense.weightLabel!),
        if (expense.vendorName != null) ('Vendor', expense.vendorName!),
        if (expense.vendorContact != null) ('Contact', expense.vendorContact!),
      ];
}
