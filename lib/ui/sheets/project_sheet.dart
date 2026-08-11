import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../widgets/fields.dart';
import '../widgets/primitives.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';

/// Creates a project, or edits an existing one. On create the stage ladder is
/// editable up front — most builds want their own rungs from day one.
Future<ProjectView?> openProjectSheet(
  BuildContext context,
  WidgetRef ref, {
  ProjectView? project,
}) {
  return Navigator.of(context, rootNavigator: true).push<ProjectView>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ProjectSheet(project: project),
    ),
  );
}

class _ProjectSheet extends ConsumerStatefulWidget {
  const _ProjectSheet({this.project});

  final ProjectView? project;

  @override
  ConsumerState<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends ConsumerState<_ProjectSheet> {
  late final bool _editing = widget.project != null;

  late final _name = TextEditingController(text: widget.project?.name ?? '');
  late final _location = TextEditingController(text: widget.project?.location ?? '');
  late final _currency = TextEditingController(text: widget.project?.currency ?? 'Rs');
  late final _plotSize = TextEditingController(text: plainNumber(widget.project?.plotSize));
  late String _plotSizeUnit = widget.project?.plotSizeUnit ?? 'Marla';
  late String? _startedOn = widget.project?.startedOn ?? todayIso();

  late final List<String> _stages = [...kDefaultStages];

  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _currency.dispose();
    _plotSize.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _errors = {});

    final size = parseDecimal(_plotSize.text);
    if (size != null && size.isNaN) {
      setState(() => _errors = {'plotSize': 'That is not a number.'});
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);

    try {
      final ProjectView saved;
      if (_editing) {
        saved = await repo.updateProject(
          widget.project!.id,
          name: _name.text.trim(),
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          plotSize: size,
          plotSizeUnit: _plotSizeUnit.trim().isEmpty ? 'Marla' : _plotSizeUnit.trim(),
          // An emptied box means "remove the tag", not "leave it alone".
          clearPlotSize: size == null,
          startedOn: _startedOn,
          currency: _currency.text.trim().isEmpty ? 'Rs' : _currency.text.trim(),
        );
      } else {
        saved = await repo.createProject(
          name: _name.text.trim(),
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          plotSize: size,
          plotSizeUnit: _plotSizeUnit.trim().isEmpty ? 'Marla' : _plotSizeUnit.trim(),
          startedOn: _startedOn,
          currency: _currency.text.trim().isEmpty ? 'Rs' : _currency.text.trim(),
          stages: _stages,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
      Toast.success(context, _editing ? 'Project updated.' : '${saved.name} is on the books.');
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
      title: _editing ? 'Project details' : 'Start a project',
      subtitle: _editing ? widget.project!.name : 'New build',
      actions: [
        Btn(
          label: 'Cancel',
          kind: BtnKind.secondary,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        Btn(
          label: _editing ? 'Save changes' : 'Create project',
          busy: _busy,
          onPressed: _save,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: 'Project name',
            error: _errors['name'],
            child: BunyadInput(
              controller: _name,
              hintText: 'Gulberg III — 1 Kanal House',
              maxLength: 140,
              autofocus: !_editing,
              invalid: _errors.containsKey('name'),
            ),
          ),
          const SizedBox(height: 18),

          Field(
            label: 'City or area',
            error: _errors['location'],
            child: BunyadInput(
              controller: _location,
              hintText: 'Lahore',
              maxLength: 140,
              invalid: _errors.containsKey('location'),
            ),
          ),
          const SizedBox(height: 18),

          // Plot size is a value plus a unit, so "3.5 Marla", "5 Marla" and
          // "1 Kanal" all work.
          Field(
            label: 'Plot size',
            error: _errors['plotSize'],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BunyadInput.decimal(
                    controller: _plotSize,
                    hintText: '3.5',
                    invalid: _errors.containsKey('plotSize'),
                  ),
                ),
                const SizedBox(width: T.s2),
                SizedBox(
                  width: 130,
                  child: BunyadSelect<String>(
                    value: kPlotSizeUnits.contains(_plotSizeUnit)
                        ? _plotSizeUnit
                        : kPlotSizeUnits.first,
                    items: [for (final unit in kPlotSizeUnits) (value: unit, label: unit)],
                    onChanged: (value) => setState(() => _plotSizeUnit = value ?? 'Marla'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          FieldGrid(
            children: [
              Field(
                label: _editing ? 'Started on' : 'Start date',
                error: _errors['startedOn'],
                child: DateField(
                  value: _startedOn,
                  lastDate: DateTime.now(),
                  onChanged: (value) => setState(() => _startedOn = value),
                ),
              ),
              Field(
                label: 'Currency label',
                error: _errors['currency'],
                child: BunyadInput(
                  controller: _currency,
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  invalid: _errors.containsKey('currency'),
                ),
              ),
            ],
          ),

          if (!_editing) ...[
            const SizedBox(height: T.s6),
            Text(
              'Stages — the ladder this build climbs',
              style: TextStyle(fontFamily: T.fontFamily, fontSize: 12, color: T.ink(0.7)),
            ),
            const SizedBox(height: 4),
            Text(
              'Rename, reorder or remove any of these later. Plot stages get their own '
              'suggestions: plot cost, map, approval, procession, society.',
              style: T.body.copyWith(fontSize: 12, color: T.ink(0.55)),
            ),
            const SizedBox(height: T.s3),
            Wrap(
              spacing: T.s2,
              runSpacing: T.s2,
              children: [
                for (var i = 0; i < _stages.length; i++)
                  BunyadChip(
                    label: _stages[i],
                    neutral: true,
                    onRemove: () => setState(() => _stages.removeAt(i)),
                  ),
                BunyadChip(
                  label: 'Add stage',
                  icon: Icons.add_rounded,
                  onTap: _addStage,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addStage() async {
    final name = await promptForText(
      context,
      title: 'Name the stage',
      hintText: 'Roof, Plaster, Boundary Wall…',
      confirmLabel: 'Add stage',
    );
    if (name == null || name.isEmpty) return;

    if (_stages.any((s) => s.toLowerCase() == name.toLowerCase())) {
      if (mounted) Toast.error(context, '"$name" is already on the ladder.');
      return;
    }
    setState(() => _stages.add(name));
  }
}

/// The web app reaches for `window.prompt` in two places — naming a stage and
/// naming an expense head. This is the same thing, drawn properly.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String? body,
  String? hintText,
  String confirmLabel = 'Add',
}) async {
  final controller = TextEditingController();

  final result = await showDialog<String>(
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
            child: Text(title, style: T.heading(20)),
          ),
          Padding(
            padding: const EdgeInsets.all(T.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (body != null) ...[
                  Text(body, style: T.body.copyWith(fontSize: 13, color: T.ink(0.7))),
                  const SizedBox(height: T.s3),
                ],
                BunyadInput(
                  controller: controller,
                  hintText: hintText,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
                ),
              ],
            ),
          ),
          Container(
            color: T.raised,
            padding: const EdgeInsets.all(T.s3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Btn(
                  label: 'Cancel',
                  kind: BtnKind.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: T.s2),
                Btn(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return result;
}
