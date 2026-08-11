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

/// Adds a stage or edits one. `kind` decides which heads the stage suggests —
/// plot stages offer plot cost, map, approval, procession and society charges;
/// everything else offers the material list.
///
/// Returns the whole project back, because the server recomputes every stage's
/// share of the total when one changes.
Future<ProjectView?> openStageSheet(
  BuildContext context, {
  required String projectId,
  StageCard? stage,
}) {
  return Navigator.of(context, rootNavigator: true).push<ProjectView>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _StageSheet(projectId: projectId, stage: stage),
    ),
  );
}

class _StageSheet extends ConsumerStatefulWidget {
  const _StageSheet({required this.projectId, this.stage});

  final String projectId;
  final StageCard? stage;

  @override
  ConsumerState<_StageSheet> createState() => _StageSheetState();
}

class _StageSheetState extends ConsumerState<_StageSheet> {
  late final bool _editing = widget.stage != null;

  late final _name = TextEditingController(text: widget.stage?.name ?? '');
  late final _plannedNote = TextEditingController(text: widget.stage?.plannedNote ?? '');

  late StageKind _kind = widget.stage?.kind ?? StageKind.build;
  late StageStatus _status = widget.stage?.status ?? StageStatus.notStarted;
  late String? _startedOn = widget.stage?.startedOn;
  late String? _completedOn = widget.stage?.completedOn;

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _name.dispose();
    _plannedNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errors = {};
    });

    final repo = ref.read(repositoryProvider);
    final name = _name.text.trim();

    try {
      final project = _editing
          ? await repo.updateStage(
              widget.projectId,
              widget.stage!.id,
              name: name,
              kind: _kind,
              status: _status,
              startedOn: _startedOn,
              completedOn: _completedOn,
              plannedNote: _plannedNote.text.trim(),
            )
          : await repo.createStage(
              widget.projectId,
              name: name,
              kind: _kind,
              status: _status,
              plannedNote: _plannedNote.text.trim(),
            );

      if (!mounted) return;
      Navigator.of(context).pop(project);
      Toast.success(context, _editing ? 'Stage updated.' : '$name added to the ladder.');
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
      title: _editing ? 'Stage details' : 'Add a stage',
      subtitle: _editing ? widget.stage!.name : 'This ladder is yours',
      actions: [
        Btn(
          label: 'Cancel',
          kind: BtnKind.secondary,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        Btn(label: _editing ? 'Save stage' : 'Add stage', busy: _busy, onPressed: _save),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: 'Stage name',
            error: _errors['name'],
            child: BunyadInput(
              controller: _name,
              hintText: 'Roof, Plaster, Boundary Wall…',
              maxLength: 100,
              autofocus: !_editing,
              invalid: _errors.containsKey('name'),
            ),
          ),
          const SizedBox(height: 18),

          Field(
            label: 'What kind of stage is this?',
            error: _errors['kind'],
            child: BunyadSelect<StageKind>(
              value: _kind,
              items: const [
                (
                  value: StageKind.build,
                  label: 'Construction — suggests bricks, cement, steel, labour…'
                ),
                (
                  value: StageKind.plot,
                  label: 'Plot / land — suggests plot cost, map, approval, procession, society'
                ),
              ],
              onChanged: (value) => setState(() => _kind = value ?? StageKind.build),
            ),
          ),
          const SizedBox(height: 18),

          Field(
            label: 'Status',
            error: _errors['status'],
            child: BunyadSelect<StageStatus>(
              value: _status,
              items: const [
                (value: StageStatus.notStarted, label: 'Not started'),
                (value: StageStatus.inProgress, label: 'In progress'),
                (value: StageStatus.complete, label: 'Complete'),
              ],
              onChanged: (value) => setState(() => _status = value ?? StageStatus.notStarted),
            ),
          ),
          const SizedBox(height: 18),

          FieldGrid(
            children: [
              Field(
                label: 'Started on',
                error: _errors['startedOn'],
                child: DateField(
                  value: _startedOn,
                  onChanged: (value) => setState(() => _startedOn = value),
                ),
              ),
              Field(
                label: 'Completed on',
                error: _errors['completedOn'],
                child: DateField(
                  value: _completedOn,
                  onChanged: (value) => setState(() => _completedOn = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Field(
            label: 'Note while it is unscheduled',
            error: _errors['plannedNote'],
            child: BunyadInput(
              controller: _plannedNote,
              hintText: 'Planned Sep 2026',
              maxLength: 140,
              invalid: _errors.containsKey('plannedNote'),
            ),
          ),
          const SizedBox(height: T.s4),
        ],
      ),
    );
  }
}
