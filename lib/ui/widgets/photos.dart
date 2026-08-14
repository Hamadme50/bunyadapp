import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/tokens.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../global.dart';
import '../../state/session.dart';
import 'primitives.dart';
import 'toast.dart';

/// A stored photo, fetched with the bearer token attached. Images live behind
/// the same access rules as the project, so they cannot be plain URLs.
class ApiImage extends ConsumerWidget {
  const ApiImage({
    super.key,
    required this.fileId,
    this.thumbnail = true,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String fileId;
  final bool thumbnail;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(apiClientProvider).imageHeaders;

    return CachedNetworkImage(
      imageUrl: thumbnail ? Api.thumbnailUrl(fileId) : Api.fileUrl(fileId),
      httpHeaders: headers,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: T.tFast,
      placeholder: (context, _) => const ColoredBox(
        color: T.neutral200,
        child: Center(child: Spinner(size: 16)),
      ),
      errorWidget: (context, _, __) => const ColoredBox(
        color: T.neutral200,
        child: Icon(Icons.broken_image_outlined, size: 18, color: T.neutral600),
      ),
    );
  }
}

/// What a PDF bill looks like in a strip of photos.
///
/// There is no preview to show: the server stores a document whole and never
/// renders a thumbnail from it. So the tile says what the file is instead —
/// the mark and the filename, which is the part a person is scanning for.
class PdfTile extends StatelessWidget {
  const PdfTile({super.key, required this.filename, this.compact = false});

  final String filename;

  /// The 46px strip tile, too small for a filename to be worth showing.
  final bool compact;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: T.accent100,
        child: Padding(
          padding: EdgeInsets.all(compact ? 4 : 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: compact ? 20 : 26,
                color: T.accent700,
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  filename,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: T.body.copyWith(
                    fontSize: 9,
                    height: 1.2,
                    color: T.accent800,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Opens a stored PDF in whatever the phone uses to read documents.
///
/// The file is behind the bearer token, so it cannot simply be launched as a
/// URL — it comes down to a temp file first. Returns once the viewer is open,
/// or reports why it is not.
Future<void> openStoredPdf(BuildContext context, WidgetRef ref, FileView file) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void report(String message) {
    messenger?.hideCurrentSnackBar();
    Toast.error(context, message);
  }

  try {
    final path = await ref.read(repositoryProvider).downloadToCache(file);
    final opened = await OpenFilex.open(path, type: 'application/pdf');
    if (opened.type != ResultType.done && context.mounted) {
      // Most often "no app found" — a phone with no PDF reader installed.
      report('Could not open ${file.filename}. Install a PDF reader and try again.');
    }
  } on ApiException catch (failure) {
    if (context.mounted) report(failure.message);
  } catch (_) {
    if (context.mounted) report('Could not open ${file.filename}.');
  }
}

/// `.thumb` — a 46px tile in an expense's photo strip.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.fileId, required this.onTap, this.size = 46});

  final String fileId;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: T.neutral200,
            borderRadius: T.brSm,
            border: Border.all(color: T.hairline),
            boxShadow: T.shadowXs,
          ),
          child: ApiImage(fileId: fileId),
        ),
      );
}

/// The PDF equivalent of [PhotoThumb] — same 46px tile, no preview inside it.
class PdfThumb extends StatelessWidget {
  const PdfThumb({super.key, required this.filename, required this.onTap, this.size = 46});

  final String filename;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Open $filename',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: T.accent100,
              borderRadius: T.brSm,
              border: Border.all(color: T.hairline),
              boxShadow: T.shadowXs,
            ),
            child: PdfTile(filename: filename, compact: true),
          ),
        ),
      );
}

/// One photo in the lightbox.
class LightboxPhoto {
  const LightboxPhoto({required this.fileId, required this.caption});

  final String fileId;
  final String caption;
}

/// `.lightbox` — full-bleed, pinch to zoom, swipe between an expense's photos.
Future<void> openLightbox(
  BuildContext context,
  List<LightboxPhoto> photos,
  int startIndex,
) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: T.neutral900.withValues(alpha: 0.88),
      transitionDuration: T.tFast,
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _Lightbox(photos: photos, startIndex: startIndex),
      ),
    ),
  );
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({required this.photos, required this.startIndex});

  final List<LightboxPhoto> photos;
  final int startIndex;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final PageController _controller = PageController(initialPage: widget.startIndex);
  late int _index = widget.startIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: ApiImage(fileId: widget.photos[i].fileId, thumbnail: false, fit: BoxFit.contain),
              ),
            ),
          ),

          // The bar the web app puts under the frame: caption, count, close.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: T.raised,
              padding: EdgeInsets.fromLTRB(
                T.s4,
                T.s3,
                T.s4,
                T.s3 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          photo.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: T.heading(15),
                        ),
                        if (widget.photos.length > 1) ...[
                          const SizedBox(height: 2),
                          Text('${_index + 1} of ${widget.photos.length}', style: T.muted),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: T.s3),
                  Btn(
                    label: 'Close',
                    kind: BtnKind.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + T.s2,
            right: T.s3,
            child: IconBtn(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
