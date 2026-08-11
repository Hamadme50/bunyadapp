import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../global.dart';
import '../../state/session.dart';
import 'primitives.dart';

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
