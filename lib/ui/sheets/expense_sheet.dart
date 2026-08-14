import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../global.dart';
import '../../state/session.dart';
import '../widgets/fields.dart';
import '../widgets/photos.dart';
import '../widgets/primitives.dart';
import '../widgets/sheet.dart';
import '../widgets/toast.dart';

/// The single form behind every expense — same shape whichever stage it is
/// filed on, only the suggested heads change.
///
/// Returns true when something was saved, so the stage screen knows to reload.
Future<bool?> openExpenseSheet(
  BuildContext context, {
  required String projectId,
  required StageCard stage,
  required String projectName,
  required String currency,
  List<String> suggestions = const [],
  ExpenseView? expense,
  String? presetHead,
}) {
  return Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ExpenseSheet(
        projectId: projectId,
        stage: stage,
        projectName: projectName,
        currency: currency,
        suggestions: suggestions,
        expense: expense,
        presetHead: presetHead,
      ),
    ),
  );
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({
    required this.projectId,
    required this.stage,
    required this.projectName,
    required this.currency,
    required this.suggestions,
    this.expense,
    this.presetHead,
  });

  final String projectId;
  final StageCard stage;
  final String projectName;
  final String currency;
  final List<String> suggestions;
  final ExpenseView? expense;
  final String? presetHead;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  late final bool _editing = widget.expense != null;

  late final _name = TextEditingController(text: widget.expense?.name ?? '');
  late final _quantity = TextEditingController(text: plainNumber(widget.expense?.quantity));
  late final _quantityUnit = TextEditingController(text: widget.expense?.quantityUnit ?? '');
  late final _weight = TextEditingController(text: plainNumber(widget.expense?.weight));
  late final _vendorName = TextEditingController(text: widget.expense?.vendorName ?? '');
  late final _vendorContact = TextEditingController(text: widget.expense?.vendorContact ?? '');
  late final _amount = TextEditingController(text: plainNumber(widget.expense?.amount));
  late final _notes = TextEditingController(text: widget.expense?.notes ?? '');

  /// The chosen head, whether tapped from a chip or typed in.
  late String _head = widget.expense?.head ?? widget.presetHead ?? '';
  late final _headInput = TextEditingController(
    text: widget.suggestions.contains(_head) ? '' : _head,
  );

  late WeightUnit _weightUnit = widget.expense?.weightUnit ?? WeightUnit.kg;
  late String? _expenseDate = widget.expense?.expenseDate ?? todayIso();

  /// Ids of uploaded files, in the order they should show.
  // The whole view, not just the id: a tile has to know whether it is a photo
  // to preview or a PDF to draw as a document.
  late final List<FileView> _files = [...?widget.expense?.files];

  int _inFlightUploads = 0;
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _quantityUnit.dispose();
    _weight.dispose();
    _vendorName.dispose();
    _vendorContact.dispose();
    _amount.dispose();
    _notes.dispose();
    _headInput.dispose();
    super.dispose();
  }

  bool _sameHead(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  // ── photos ──────────────────────────────────────────────────────────────

  Future<void> _pickPhotos(ImageSource source) async {
    final picker = ImagePicker();
    final List<XFile> files;

    try {
      if (source == ImageSource.camera) {
        final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 92);
        files = shot == null ? const [] : [shot];
      } else {
        files = await picker.pickMultiImage(imageQuality: 92);
      }
    } catch (failure) {
      if (mounted) Toast.error(context, 'Could not open the camera or gallery.');
      return;
    }
    if (files.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    for (final file in files) {
      if (!mounted) return;
      setState(() => _inFlightUploads += 1);
      try {
        final stored = await repo.uploadPhoto(
          filePath: file.path,
          filename: file.name,
          projectId: widget.projectId,
        );
        if (mounted) setState(() => _files.add(stored));
      } on ApiException catch (failure) {
        if (mounted) Toast.error(context, '${file.name}: ${failure.message}');
      } finally {
        if (mounted) setState(() => _inFlightUploads -= 1);
      }
    }
  }

  /// Attaching a PDF rather than a picture. [image_picker] only ever offers
  /// images, so a document needs the system file picker.
  Future<void> _pickDocument() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
        withData: false,
      );
    } catch (failure) {
      if (mounted) Toast.error(context, 'Could not open your files.');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    for (final file in picked.files) {
      final path = file.path;
      if (path == null) continue;
      if (!mounted) return;
      setState(() => _inFlightUploads += 1);
      try {
        final stored = await repo.uploadPhoto(
          filePath: path,
          filename: file.name,
          projectId: widget.projectId,
        );
        if (mounted) setState(() => _files.add(stored));
      } on ApiException catch (failure) {
        if (mounted) Toast.error(context, '${file.name}: ${failure.message}');
      } finally {
        if (mounted) setState(() => _inFlightUploads -= 1);
      }
    }
  }

  Future<void> _choosePhotoSource() async {
    final choice = await showModalBottomSheet<_Attachment>(
      context: context,
      backgroundColor: T.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rLg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: T.s2),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: T.accent),
              title: Text('Take a photo', style: T.body.copyWith(fontSize: 15)),
              onTap: () => Navigator.of(context).pop(_Attachment.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: T.accent),
              title: Text('Choose from gallery', style: T.body.copyWith(fontSize: 15)),
              onTap: () => Navigator.of(context).pop(_Attachment.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: T.accent),
              title: Text('Choose a PDF', style: T.body.copyWith(fontSize: 15)),
              subtitle: Text(
                'An emailed invoice or a scanned bill',
                style: T.body.copyWith(fontSize: 12, color: T.ink(0.55)),
              ),
              onTap: () => Navigator.of(context).pop(_Attachment.document),
            ),
            const SizedBox(height: T.s2),
          ],
        ),
      ),
    );

    switch (choice) {
      case _Attachment.camera:
        await _pickPhotos(ImageSource.camera);
      case _Attachment.gallery:
        await _pickPhotos(ImageSource.gallery);
      case _Attachment.document:
        await _pickDocument();
      case null:
        break;
    }
  }

  // ── saving ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _errors = {});

    final chosenHead = _head.trim().isNotEmpty ? _head.trim() : _headInput.text.trim();
    if (chosenHead.isEmpty) {
      setState(() => _errors = {'head': 'Pick a head or type your own.'});
      return;
    }

    final amount = parseDecimal(_amount.text);
    if (amount == null || amount.isNaN) {
      setState(() => _errors = {'amount': 'Enter the amount.'});
      return;
    }

    final quantity = parseDecimal(_quantity.text);
    if (quantity != null && quantity.isNaN) {
      setState(() => _errors = {'quantity': 'That is not a number.'});
      return;
    }

    final weight = parseDecimal(_weight.text);
    if (weight != null && weight.isNaN) {
      setState(() => _errors = {'weight': 'That is not a number.'});
      return;
    }

    if (_inFlightUploads > 0) {
      Toast.info(context, 'Hold on — photos are still uploading.');
      return;
    }

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'head': chosenHead,
      'quantity': quantity,
      'quantityUnit': _quantityUnit.text.trim().isEmpty ? null : _quantityUnit.text.trim(),
      'weight': weight,
      'weightUnit': weight == null ? null : _weightUnit.wire,
      'vendorName': _vendorName.text.trim().isEmpty ? null : _vendorName.text.trim(),
      'vendorContact': _vendorContact.text.trim().isEmpty ? null : _vendorContact.text.trim(),
      'amount': amount,
      'expenseDate': _expenseDate,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'fileIds': [for (final file in _files) file.id],
    };

    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);

    try {
      final saved = _editing
          ? await repo.updateExpense(widget.expense!.id, payload)
          : await repo.createExpense(widget.projectId, widget.stage.id, payload);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      Toast.success(
        context,
        _editing ? 'Expense updated.' : '${saved.name} added to ${widget.stage.name}.',
      );
    } on ApiException catch (failure) {
      if (!mounted) return;
      setState(() => _errors = failure.fields ?? {});
      Toast.error(context, failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return BunyadSheetScaffold(
      title: _editing ? 'Edit expense' : 'Add an expense',
      subtitle: '${widget.projectName} · ${widget.stage.name}',
      footNote: _editing
          ? 'Logged by ${widget.expense!.createdByName}. Your name goes on the edit.'
          : 'Logged as ${user?.name ?? 'you'} — your name is stamped on this entry.',
      actions: [
        Btn(
          label: 'Cancel',
          kind: BtnKind.secondary,
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        Btn(
          label: _editing ? 'Save changes' : 'Save expense',
          busy: _busy,
          onPressed: _save,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(
            label: 'Expense name',
            error: _errors['name'],
            child: BunyadInput(
              controller: _name,
              hintText: 'e.g. Sariya 12mm — 3rd lot',
              maxLength: 160,
              invalid: _errors.containsKey('name'),
            ),
          ),
          const SizedBox(height: 20),

          _headPicker(),
          const SizedBox(height: 20),

          FieldGrid(
            children: [
              Field(
                label: 'Quantity',
                error: _errors['quantity'],
                child: Row(
                  children: [
                    Expanded(
                      child: BunyadInput.decimal(
                        controller: _quantity,
                        hintText: '84',
                        invalid: _errors.containsKey('quantity'),
                      ),
                    ),
                    const SizedBox(width: T.s2),
                    SizedBox(
                      width: 116,
                      child: BunyadInput(
                        controller: _quantityUnit,
                        hintText: 'bags…',
                        maxLength: 24,
                        textCapitalization: TextCapitalization.none,
                        suffix: _unitMenu(),
                      ),
                    ),
                  ],
                ),
              ),
              Field(
                label: 'Weight',
                error: _errors['weight'],
                child: Row(
                  children: [
                    Expanded(
                      child: BunyadInput.decimal(
                        controller: _weight,
                        hintText: '4.2',
                        invalid: _errors.containsKey('weight'),
                      ),
                    ),
                    const SizedBox(width: T.s2),
                    SegmentedPair<WeightUnit>(
                      value: _weightUnit,
                      first: (value: WeightUnit.kg, label: 'kg'),
                      second: (value: WeightUnit.ton, label: 'ton'),
                      onChanged: (value) => setState(() => _weightUnit = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          FieldGrid(
            children: [
              Field(
                label: 'Date of expense',
                error: _errors['expenseDate'],
                child: DateField(
                  value: _expenseDate,
                  lastDate: DateTime.now(),
                  onChanged: (value) => setState(() => _expenseDate = value),
                ),
              ),
              Field(
                label: 'Amount (${widget.currency})',
                error: _errors['amount'],
                child: BunyadInput.decimal(
                  controller: _amount,
                  hintText: '592,000',
                  invalid: _errors.containsKey('amount'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          FieldGrid(
            children: [
              Field(
                label: 'Vendor name',
                error: _errors['vendorName'],
                child: BunyadInput(
                  controller: _vendorName,
                  hintText: 'Al-Rehman Steel Traders',
                  maxLength: 140,
                  invalid: _errors.containsKey('vendorName'),
                ),
              ),
              Field(
                label: 'Vendor contact',
                error: _errors['vendorContact'],
                child: BunyadInput(
                  controller: _vendorContact,
                  hintText: '0300 421 8877',
                  keyboardType: TextInputType.phone,
                  maxLength: 60,
                  invalid: _errors.containsKey('vendorContact'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _photos(),
          const SizedBox(height: 20),

          Field(
            label: 'Notes',
            error: _errors['notes'],
            child: BunyadInput(
              controller: _notes,
              hintText: 'Anything worth remembering about this delivery (optional)',
              maxLines: 3,
              maxLength: 2000,
              invalid: _errors.containsKey('notes'),
            ),
          ),
          const SizedBox(height: T.s4),
        ],
      ),
    );
  }

  /// The chips this stage suggests, then "or", then a box for a new head.
  Widget _headPicker() {
    return Field(
      label: 'Material or head',
      error: _errors['head'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.suggestions.isNotEmpty)
            Wrap(
              spacing: T.s2,
              runSpacing: T.s2,
              children: [
                for (final suggestion in widget.suggestions)
                  BunyadChip(
                    label: suggestion,
                    pressed: _sameHead(suggestion, _head),
                    onTap: () {
                      setState(() {
                        _head = suggestion;
                        _headInput.clear();
                      });
                    },
                  ),
              ],
            ),
          const SizedBox(height: T.s3),
          Row(
            children: [
              Text('or', style: T.body.copyWith(fontSize: 12, color: T.ink(0.55))),
              const SizedBox(width: T.s2),
              Expanded(
                child: BunyadInput(
                  controller: _headInput,
                  hintText: 'Type a new head',
                  maxLength: 60,
                  invalid: _errors.containsKey('head'),
                  onChanged: (value) => setState(() => _head = value.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The unit shortcuts the web app offers through a `<datalist>`.
  Widget _unitMenu() => PopupMenuButton<String>(
        tooltip: 'Common units',
        icon: const Icon(Icons.expand_more_rounded, size: 18, color: T.neutral600),
        onSelected: (unit) => setState(() => _quantityUnit.text = unit),
        itemBuilder: (context) => [
          for (final unit in kQuantityUnits)
            PopupMenuItem<String>(
              value: unit,
              child: Text(unit, style: T.body.copyWith(fontSize: 14)),
            ),
        ],
      );

  /// `.dropzone` plus the tiles. A phone has no drag and drop, so the zone is
  /// a button that offers the camera or the gallery.
  Widget _photos() {
    return Field(
      label: 'Attachments — bills, delivery slips, the pile on site',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _choosePhotoSource,
            borderRadius: T.brCard,
            child: DottedZone(
              child: Row(
                children: [
                  const Icon(Icons.add_a_photo_outlined, size: 22, color: T.accent),
                  const SizedBox(width: T.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Add a photo or a PDF', style: T.heading(14)),
                        const SizedBox(height: 2),
                        Text(
                          'Photograph the bill, pick one from your gallery, or attach an '
                          'emailed PDF invoice. They all stay with this expense.',
                          style: T.body.copyWith(fontSize: 12, color: T.ink(0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_files.isNotEmpty || _inFlightUploads > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final file in _files) _tile(file),
                for (var i = 0; i < _inFlightUploads; i++)
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: T.neutral200,
                      borderRadius: T.brCard,
                      border: Border.all(color: T.hairline),
                    ),
                    child: const Spinner(size: 18),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(FileView file) => SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: T.brCard,
              // A PDF has no preview to load — the server never renders one —
              // so it gets a document tile carrying its filename instead.
              child: file.isPdf
                  ? PdfTile(filename: file.filename)
                  : ApiImage(fileId: file.id),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: T.text.withValues(alpha: 0.82),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _files.remove(file)),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.close_rounded, size: 14, color: T.bg),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// `.dropzone` — the dashed panel that invites a photo.
class DottedZone extends StatelessWidget {
  const DottedZone({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(T.s4),
        decoration: BoxDecoration(
          color: T.raised,
          borderRadius: T.brCard,
          border: Border.all(color: T.hairlineStrong, width: 1.5),
        ),
        child: child,
      );
}

/// What the attach sheet offers. Not [ImageSource]: a PDF is not an image, and
/// the third option goes through the system file picker instead.
enum _Attachment { camera, gallery, document }
