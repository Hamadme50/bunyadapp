import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_upgrade_version/flutter_upgrade_version.dart';

/// Google Play's in-app update, run as the blocking IMMEDIATE flow.
///
/// Play downloads and installs the new version inside a full-screen activity of
/// its own and restarts the app; there is no "later" button. Bunyad is a client
/// for an API that moves with it, so an old build in the field is a build
/// talking to endpoints that may have changed underneath it.
///
/// This is a no-op unless the running build was installed from Google Play and
/// a higher version code is live on the user's track — so a debug run, a
/// sideloaded APK and an already-current install all cost one silent call.
class AppUpdate {
  const AppUpdate._();

  /// Called once at launch. Starts the update if Play has one.
  static Future<void> check() => _run(onlyWhenAlreadyStarted: false);

  /// Called when the app comes back to the foreground.
  ///
  /// Deliberately narrower than [check]: it resumes an update that was already
  /// under way and got interrupted, and does nothing otherwise. Re-offering
  /// every available update here would mean a user who backs out of Play's
  /// screen is handed it again the moment they return — a loop with no way
  /// into the app.
  static Future<void> resumeIfInterrupted() => _run(onlyWhenAlreadyStarted: true);

  static Future<void> _run({required bool onlyWhenAlreadyStarted}) async {
    // Play Store only. On iOS the channel does not exist, and an App Store
    // build cannot install an update from inside the app at all.
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final manager = InAppUpdateManager();
      final info = await manager.checkForUpdate();
      if (info == null) return;

      final started = info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress;
      final available = info.updateAvailability == UpdateAvailability.updateAvailable;

      if (!(started || (available && !onlyWhenAlreadyStarted))) return;

      if (info.immediateAllowed) {
        await manager.startAnUpdate(type: AppUpdateType.immediate);
      } else if (info.flexibleAllowed) {
        // Some releases and devices cannot do the blocking flow. Downloading in
        // the background still beats leaving them on the old build.
        await manager.startAnUpdate(type: AppUpdateType.flexible);
      }
    } catch (failure) {
      // Never let a store check keep somebody out of their own books. A missing
      // Play Store, no network, a sideloaded build — all land here.
      debugPrint('In-app update check skipped: $failure');
    }
  }
}
