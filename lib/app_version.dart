/// Single source of truth for the version shown in the About panel.
///
/// Keep this in sync with `pubspec.yaml`. `scripts/check_branding.py` fails
/// when the two disagree, so the About panel cannot silently drift again.
const String appVersion = '1.6.0';
const String appBuildNumber = '18';
const String appVersionFull = '$appVersion+$appBuildNumber';
