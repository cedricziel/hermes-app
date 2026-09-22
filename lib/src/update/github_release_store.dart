import 'dart:convert';

import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

/// Looks up the newest published release of the app on GitHub, for the
/// platforms that are not distributed through a store. Any failure reads as
/// "no update", so a rate limit or a bad connection never surfaces to the user.
class GithubReleaseStore extends UpgraderStore {
  static final _latestRelease = Uri.https(
    'api.github.com',
    '/repos/cedricziel/hermes-app/releases/latest',
  );

  @override
  Future<UpgraderVersionInfo> getVersionInfo({
    required UpgraderState state,
    required Version installedVersion,
    required String? country,
    required String? language,
  }) async {
    try {
      final response = await state.client.get(
        _latestRelease,
        headers: {
          'Accept': 'application/vnd.github+json',
          ...?state.clientHeaders,
        },
      );
      if (response.statusCode != 200) return UpgraderVersionInfo();
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = release['tag_name'] as String;
      return UpgraderVersionInfo(
        installedVersion: installedVersion,
        appStoreVersion: Version.parse(
          tag.startsWith('v') ? tag.substring(1) : tag,
        ),
        appStoreListingURL: release['html_url'] as String?,
      );
    } on Object catch (_) {
      return UpgraderVersionInfo();
    }
  }
}

/// Update checks per platform. The stores are asked about the listed build, so
/// nobody is prompted for a version that is still in review; before the app is
/// listed they find nothing and stay quiet. Linux and Windows have no store, so
/// they follow the GitHub release.
Upgrader createUpdateChecker() {
  return Upgrader(
    storeController: UpgraderStoreController(
      onAndroid: UpgraderPlayStore.new,
      oniOS: UpgraderAppStore.new,
      onMacOS: UpgraderAppStore.new,
      onLinux: GithubReleaseStore.new,
      onWindows: GithubReleaseStore.new,
    ),
  );
}
