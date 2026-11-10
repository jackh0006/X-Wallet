/// Single source of truth for the version shown in the About panel.
///
/// Keep this in sync with `pubspec.yaml`. `scripts/check_branding.py` fails
/// when the two disagree, so the About panel cannot silently drift again.
const String appVersion = '1.5.1';
const String appBuildNumber = '14';
const String appVersionFull = '$appVersion+$appBuildNumber';
