import 'package:flutter/material.dart';

import '../../core/tokens.dart';

/// `.toast` — ink-coloured for a confirmation, accent-700 for a failure, with
/// the accent bar down its left edge. Same wording and same lifetime as the
/// web app's toast stack.
class Toast {
  const Toast._();

  /// The app's own messenger, handed to [MaterialApp.scaffoldMessengerKey], so
  /// a toast can be raised from outside the widget tree.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(BuildContext context, String message) =>
      _show(ScaffoldMessenger.maybeOf(context), message, error: false);

  static void error(BuildContext context, String message) =>
      _show(ScaffoldMessenger.maybeOf(context), message, error: true);

  static void info(BuildContext context, String message) =>
      _show(ScaffoldMessenger.maybeOf(context), message, error: false);

  /// No context needed — the session ending is noticed by a listener rather
  /// than by a screen. Deferred a frame because that listener can fire while
  /// the tree is still building.
  static void global(String message, {bool error = false}) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _show(messengerKey.currentState, message, error: error),
    );
  }

  static void _show(ScaffoldMessengerState? messenger, String message, {required bool error}) {
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          duration: Duration(seconds: error ? 5 : 3),
          margin: const EdgeInsets.all(T.s4),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: T.s4, vertical: T.s3),
            decoration: BoxDecoration(
              color: error ? T.accent700 : T.text,
              borderRadius: T.brCard,
              boxShadow: T.shadowLg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  height: 20,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: error ? T.bg : T.accent,
                    borderRadius: T.brPill,
                  ),
                ),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: T.fontFamily,
                      fontSize: 13,
                      height: 1.4,
                      color: T.bg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
