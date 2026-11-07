import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'models.dart';
import 'posix_fs.dart';
import 'rpc_service.dart';

/// A lock to prevent concurrent vault operations (export/import/move/password change).
/// Exported for use by AppState.
final vaultOperationLock = Lock();

/// Serializes use of the descriptor-based advisory lock inside this VM.
/// `flock(2)` itself is cooperative and process-scoped; this local lock also
/// prevents two in-VM operations from opening distinct lock descriptors.
final _processStorageLock = Lock();
const _processStorageLockName = '.bnb-wallet-storage.lock';

/// Runs a vault/log mutation while holding the shared Linux advisory lock.
///
/// The lock object is a stable, 0600 regular file inside the validated app
/// data directory. Acquisition is nonblocking: a second wallet process gets
/// a fail-closed [StateError] and must retry after the first operation ends.
/// The lock is released by descriptor close on normal completion, exceptions,
/// and process termination. This is advisory only: a same-UID program that
/// ignores `flock` (or can replace the pathname after verification) is outside
/// its security claim.
Future<T> withProcessStorageLock<T>(Future<T> Function() operation) async {
  if (!Platform.isLinux) return operation();
  if (!PosixFs.available) {
    throw StateError(
      'Linux advisory storage lock unavailable; refusing concurrent mutation: '
      '${PosixFs.loadError}',
    );
  }
  return _processStorageLock.synchronized(() async {
    final directory = await AppStorage.getDataDirectory();
    final dirfd = PosixFs.openDirNoFollow(directory.path);
    var lockfd = -1;
    try {
      lockfd = PosixFs.openLockFileAt(dirfd, _processStorageLockName);
      if (!PosixFs.tryExclusiveLock(lockfd)) {
        throw StateError(
          'Another X Wallet process is modifying protected storage; retry '
          'after it completes.',
        );
      }
      return await operation();
    } finally {
      if (lockfd >= 0) PosixFs.closeFd(lockfd);
      PosixFs.closeFd(dirfd);
    }
  });
}

/// Acquires locks in the only permitted order: VM vault lock, then Linux
/// process lock. Vault operations use this wrapper so they cannot invert the
/// ordering used by other protected storage mutations.
Future<T> withVaultOperationLock<T>(Future<T> Function() operation) =>
    vaultOperationLock.synchronized(() => withProcessStorageLock(operation));

// Permission constants for file operations
const int _kPermMask = 511; // 0o777
const int _kNoGroupOtherPerms = 63; // 0o077 - no group/other permissions
const int _kOwnerRWPerms = 384; // 0o600 - owner read/write

/// Hard size cap for vault-class files (vault, backup envelopes, receipts).
const int _kMaxVaultBytes = 5 * 1024 * 1024;

/// Cap for in-memory shred buffers during erase (files larger than this are
/// still unlinked; overwriting flash is best-effort anyway).
const int _kMaxShredBytes = 64 * 1024 * 1024;

/// Result of an atomic write operation.
/// Distinguishes between pre-commit failures (destination untouched)
/// and post-commit durability failures (destination may be visible).
enum AtomicWriteState {
  preCommitFailure,
  committedVerified,
  committedDurabilityUncertain,
  committedVerificationFailure,
}

class AtomicWriteResult {
  const AtomicWriteResult._(this.state, this.destination, this.error);

  final AtomicWriteState state;

  /// Whether the rename commit actually occurred.
  bool get committed => state != AtomicWriteState.preCommitFailure;

  /// The rename completed but directory metadata could not be fsynced. The
  /// content was otherwise verified; callers may continue only with an
  /// explicit durability warning.
  bool get durabilityUncertain =>
      state == AtomicWriteState.committedDurabilityUncertain;

  /// The rename completed but the committed result could not be verified.
  /// Callers performing replace/restore operations must recover rather than
  /// treating this as a successful import or save.
  bool get requiresRecovery =>
      state == AtomicWriteState.committedVerificationFailure;

  /// The destination file (only meaningful if committed == true).
  final File? destination;

  /// Error message if the operation failed.
  final String? error;

  /// Pre-commit failure: destination is guaranteed unchanged.
  factory AtomicWriteResult.preCommitFailure(String error) =>
      AtomicWriteResult._(AtomicWriteState.preCommitFailure, null, error);

  /// Post-commit durability failure: rename succeeded but directory fsync or
  /// final verification failed. The new file may be visible but crash
  /// durability is uncertain.
  factory AtomicWriteResult.postCommitFailure(
    File destination,
    String error, {
    bool durabilityUncertain = false,
  }) => AtomicWriteResult._(
    durabilityUncertain
        ? AtomicWriteState.committedDurabilityUncertain
        : AtomicWriteState.committedVerificationFailure,
    destination,
    error,
  );

  /// Success: destination committed and verified.
  factory AtomicWriteResult.success(File destination) => AtomicWriteResult._(
    AtomicWriteState.committedVerified,
    destination,
    null,
  );

  /// Throws if the operation failed, otherwise returns the destination file.
  File getOrThrow() {
    if (state == AtomicWriteState.committedVerified && destination != null) {
      return destination!;
    }
    throw StateError(error ?? 'Atomic write failed');
  }
}

/// Test-only synchronization hooks for filesystem race regression tests.
///
/// Production code never assigns these. Tests install a callback, drive a
/// real [atomicWrite], and mutate the destination *between* the app's
/// validation and its commit to prove the use-time rechecks close the race.
class StorageDebugHooks {
  StorageDebugHooks._();

  /// Invoked immediately after the secure temporary file is created (its
  /// descriptor is still open and unlocked). Receives the temp file path.
  static void Function(String tempPath)? afterTempCreation;

  /// Invoked after all validations passed, immediately before the commit
  /// rename. Receives the destination path.
  static void Function(String destinationPath)? beforeCommit;

  /// Invoked immediately after the rename commit succeeds. Receives the
  /// destination path. Useful for injecting post-commit failures.
  static void Function(String destinationPath)? afterRenameCommit;

  /// Invoked before a rollback atomic write is attempted. Receives the
  /// destination path and the original blob being restored.
  static void Function(String destinationPath, String originalBlob)?
  beforeRollbackWrite;

  /// Invoked after a rollback atomic write completes (regardless of outcome).
  /// Receives the destination path and the rollback result.
  static void Function(String destinationPath, AtomicWriteResult result)?
  afterRollbackWrite;

  /// If set to true, the next directory fsync will fail with EIO.
  static bool injectFsyncFailure = false;

  /// If set to true, the next post-commit read-back verification will fail.
  static bool injectReadbackVerificationFailure = false;

  /// If set to true, the next rollback atomic write will fail before commit.
  static bool injectRollbackWriteFailure = false;

  /// Clears all hooks and injection flags. Tests must call this in teardown
  /// so no callback or flag can leak into other suites.
  static void reset() {
    afterTempCreation = null;
    beforeCommit = null;
    afterRenameCommit = null;
    beforeRollbackWrite = null;
    afterRollbackWrite = null;
    injectFsyncFailure = false;
    injectReadbackVerificationFailure = false;
    injectRollbackWriteFailure = false;
  }
}

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

/// Plain final component of [path]. Refuses degenerate names ('.', '..', '',
/// trailing-slash-only) that have no unambiguous parent/child relationship.
String _basenameOf(String path) {
  var p = path;
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  final idx = p.lastIndexOf('/');
  final base = idx < 0 ? p : p.substring(idx + 1);
  if (base.isEmpty || base == '.' || base == '..') {
    throw ArgumentError('Refusing degenerate destination path: $path');
  }
  return base;
}

/// Everything before the final component of [path]. Input must be absolute.
String _parentOf(String path) {
  final idx = path.lastIndexOf('/');
  if (idx < 0) {
    throw ArgumentError('Refusing relative destination path: $path');
  }
  return idx == 0 ? '/' : path.substring(0, idx);
}

/// Lexical (symlink-blind) normalization of [path]: collapses '.', '..' and
/// duplicate separators without touching the filesystem.
String _lexicalNormalize(String path) {
  final isAbs = path.startsWith('/');
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty && out.last != '..') {
        out.removeLast();
      } else if (!isAbs) {
        out.add('..');
      }
      continue;
    }
    out.add(part);
  }
  final joined = out.join('/');
  return isAbs ? '/$joined' : (joined.isEmpty ? '.' : joined);
}

/// Reduces a destination file name to a safe mkstemp prefix: ASCII
/// alphanumerics plus '.', '_' and '-', capped so the template fits NAME_MAX.
/// Uniqueness comes from mkstemp's random suffix, not from the prefix.
String _sanitizeTempPrefix(String baseName) {
  final sanitized = StringBuffer();
  final bytes = utf8.encode(baseName);
  for (final b in bytes) {
    final c = String.fromCharCode(b);
    final ok =
        (b >= 0x30 && b <= 0x39) || // 0-9
        (b >= 0x41 && b <= 0x5A) || // A-Z
        (b >= 0x61 && b <= 0x7A) || // a-z
        b == 0x2E ||
        b == 0x5F ||
        b == 0x2D; // . _ -
    if (ok) sanitized.write(c);
    if (sanitized.length >= 40) break;
  }
  var prefix = sanitized.toString();
  while (prefix.startsWith('.')) {
    prefix = prefix.substring(1);
  }
  if (prefix.isEmpty) prefix = 'vault';
  return prefix;
}

// ---------------------------------------------------------------------------
// Errno-aware no-follow classification
// ---------------------------------------------------------------------------

/// Classifies [path] without following a final symlink component, and — on
/// Linux — without confusing "missing" with "cannot establish state".
///
/// Linux uses the native POSIX helper (real errno): missing, regular file,
/// directory, symlink (valid or broken), special file and inaccessible are
/// all DISTINCT outcomes, and [PosixPathClass.inaccessible] callers must fail
/// closed.
///
/// Non-Linux platforms fall back to `FileSystemEntity.type(followLinks:
/// false)`. That call is documented to return `notFound` both when a path
/// does not exist AND on other lookup errors, so "missing" and "inaccessible"
/// cannot be distinguished there. This is a per-platform limitation: this
/// release targets Ubuntu Linux amd64 only, and the residual non-Linux
/// ambiguity is documented in docs/security/SECURITY_CLAIMS.md.
Future<PosixPathClass> classifyPathNoFollow(String path) async {
  if (Platform.isLinux) {
    if (!PosixFs.available) {
      // Fail closed: on Linux the errno-aware helper is the security
      // boundary; without it we must not pretend path state is knowable.
      throw StateError(
        'POSIX filesystem helper unavailable, refusing to proceed: '
        '${PosixFs.loadError}',
      );
    }
    return PosixFs.classifyNoFollow(path);
  }
  final type = await FileSystemEntity.type(path, followLinks: false);
  switch (type) {
    case FileSystemEntityType.file:
      return PosixPathClass.regularFile;
    case FileSystemEntityType.directory:
      return PosixPathClass.directory;
    case FileSystemEntityType.link:
      return PosixPathClass.symlink;
    case FileSystemEntityType.notFound:
      // AMBIGUOUS on non-Linux (missing or lookup error — see doc comment).
      // Treated as missing for API compatibility; every subsequent open/
      // create would independently fail on a real access problem.
      return PosixPathClass.missing;
    default:
      return PosixPathClass.special;
  }
}

/// Checks if [path] is a symbolic link (no-follow semantics), tolerant of
/// broken links.
///
/// Returns true ONLY for an actual symlink entry (valid or broken). Returns
/// false for a missing path or any non-symlink entry.
///
/// On Linux the classification honors the real errno: when the filesystem
/// state cannot be established (EACCES, EPERM, ELOOP, EIO, ...) this fails
/// closed with [StateError] instead of answering "not a symlink". On
/// non-Linux platforms the dart:io ambiguity documented in
/// [classifyPathNoFollow] applies.
Future<bool> isSymlink(String path) async {
  final cls = await classifyPathNoFollow(path);
  switch (cls) {
    case PosixPathClass.symlink:
      return true;
    case PosixPathClass.missing:
    case PosixPathClass.regularFile:
    case PosixPathClass.directory:
    case PosixPathClass.special:
      return false;
    case PosixPathClass.inaccessible:
      throw StateError(
        'Failed to determine if path is a symlink: filesystem state could '
        'not be established for $path.',
      );
  }
}

// ---------------------------------------------------------------------------
// Descriptor-based no-follow reads (Linux), portable fallback elsewhere
// ---------------------------------------------------------------------------

/// Reads a regular file with no-follow semantics.
///
/// Linux pipeline (descriptor-pinned, race-closed for the final path
/// component):
///   1. canonicalize the parent directory and require it to match its own
///      lexical normalization (symlinked ancestry is refused),
///   2. open the parent with O_DIRECTORY|O_NOFOLLOW (a pinned directory
///      descriptor; kernel ELOOP on a symlinked directory itself),
///   3. classify the child with fstatat(AT_SYMLINK_NOFOLLOW) — missing /
///      symlink (valid or broken) / directory / special / inaccessible,
///   4. open the child relative to the pinned descriptor with O_NOFOLLOW —
///      a symlink swapped in before the open fails with ELOOP from the
///      kernel, not from a check,
///   5. stat the descriptor (size cap) and read it fully.
///
/// Returns null when the path is missing. Throws [StateError] for every
/// unsafe or unknowable state; [missingMessage], [symlinkMessage],
/// [notRegularMessage] and [tooLargeMessage] let callers keep their exact
/// user-facing wording.
///
/// On non-Linux platforms this is the portable dart:io fallback with the
/// dart:io "notFound" ambiguity documented in [classifyPathNoFollow].
Future<String?> readRegularFileNoFollow(
  String path, {
  required int maxBytes,
  String? missingMessage,
  String? symlinkMessage,
  String? notRegularMessage,
  String? tooLargeMessage,
}) async {
  if (Platform.isLinux) {
    if (!PosixFs.available) {
      throw StateError(
        'POSIX filesystem helper unavailable, refusing to proceed: '
        '${PosixFs.loadError}',
      );
    }
    var abs = path;
    if (!abs.startsWith('/')) {
      abs = File(path).absolute.path;
    }
    final dirPath = _lexicalNormalize(_parentOf(abs));
    final base = _basenameOf(abs);

    final String parentCanonical;
    try {
      parentCanonical = PosixFs.resolveCanonical(dirPath);
    } on PosixFsError catch (e) {
      if (e.errno == errnoEnoent) {
        throw StateError(
          missingMessage ?? 'Parent directory does not exist: $dirPath',
        );
      }
      throw StateError(
        'Cannot establish state of parent directory for $path: '
        '$e (${e.meaning}).',
      );
    }
    if (parentCanonical != dirPath) {
      throw StateError(
        '$path resolves through a symlinked ancestor '
        '($parentCanonical), refusing to read.',
      );
    }

    final dirfd = PosixFs.openDirNoFollow(parentCanonical);
    try {
      final cls = PosixFs.classifyChildNoFollow(dirfd, base);
      switch (cls) {
        case PosixPathClass.missing:
          return null;
        case PosixPathClass.symlink:
          throw StateError(
            symlinkMessage ??
                'Path is a symbolic link, refusing to read: $path',
          );
        case PosixPathClass.directory:
        case PosixPathClass.special:
          throw StateError(
            notRegularMessage ?? 'Path is not a regular file: $path',
          );
        case PosixPathClass.inaccessible:
          throw StateError(
            'Cannot establish state of $path; refusing to read.',
          );
        case PosixPathClass.regularFile:
          break;
      }
      // O_NOFOLLOW|O_NONBLOCK: a symlink swapped in after the classification
      // fails the open with ELOOP from the kernel; a FIFO cannot block.
      final int fd;
      try {
        fd = PosixFs.openReadNoFollow(dirfd, base);
      } on PosixFsError catch (e) {
        if (e.errno == errnoEloop) {
          // The entry became a symlink between classification and open —
          // exactly the race O_NOFOLLOW exists to stop. Refuse.
          throw StateError(
            symlinkMessage ??
                'Path is a symbolic link, refusing to read: $path',
          );
        }
        if (e.errno == errnoEacces || e.errno == errnoEperm) {
          throw StateError(
            'Cannot establish state of $path; refusing to read.',
          );
        }
        rethrow;
      }
      try {
        final st = PosixFs.statFd(fd);
        if (!st.isRegular) {
          throw StateError(
            notRegularMessage ?? 'Path is not a regular file: $path',
          );
        }
        if (st.size > maxBytes) {
          throw StateError(
            tooLargeMessage ??
                'File exceeds maximum size of $maxBytes bytes: $path',
          );
        }
        final bytes = PosixFs.readAllFromFd(fd, maxBytes: maxBytes);
        try {
          return utf8.decode(bytes, allowMalformed: false);
        } on FormatException {
          throw StateError('File is not valid UTF-8 text: $path');
        }
      } finally {
        PosixFs.closeFd(fd);
      }
    } finally {
      PosixFs.closeFd(dirfd);
    }
  }

  // ---- portable fallback (non-Linux) ----
  final type = await FileSystemEntity.type(path, followLinks: false);
  switch (type) {
    case FileSystemEntityType.link:
      throw StateError(
        symlinkMessage ?? 'Path is a symbolic link, refusing to read: $path',
      );
    case FileSystemEntityType.directory:
      throw StateError(
        notRegularMessage ?? 'Path is not a regular file: $path',
      );
    case FileSystemEntityType.notFound:
      return null; // documented non-Linux ambiguity
    case FileSystemEntityType.file:
      final stat = await File(path).stat();
      if (stat.size > maxBytes) {
        throw StateError(
          tooLargeMessage ??
              'File exceeds maximum size of $maxBytes bytes: $path',
        );
      }
      return await File(path).readAsString();
    default:
      throw StateError(
        notRegularMessage ?? 'Path is not a regular file: $path',
      );
  }
}

// ---------------------------------------------------------------------------
// Secure temporary file + atomic write
// ---------------------------------------------------------------------------

/// Creates a secure temporary file in the same directory as [destination]
/// (portable dart:io fallback used on non-Linux only).
///
/// On Linux the caller uses [PosixFs.mkstempSecure] instead, which guarantees
/// mode 0600 AT CREATION via mkstemp's explicit mode argument — the kernel
/// umask can only clear bits, never add them.
Future<File> _createSecureTempFile(File destination) async {
  final parent = destination.parent;
  if (!await parent.exists()) {
    throw StateError('Destination directory does not exist: ${parent.path}');
  }
  // Check if parent is a symlink (no-follow semantics)
  if (await isSymlink(parent.path)) {
    throw StateError(
      'Destination parent directory is a symlink, refusing to write.',
    );
  }

  String tempName;
  File? tempFile;

  // Try a few times to get a unique name
  for (var attempt = 0; attempt < 10; attempt++) {
    final randomPart = List<int>.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    );
    final hex = randomPart
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    tempName = '.${destination.uri.pathSegments.last}.tmp.$hex';
    tempFile = File('${parent.path}/$tempName');
    if (!await tempFile.exists()) break;
    if (attempt == 9) {
      throw StateError('Could not generate unique temporary filename');
    }
  }
  // Create the file exclusively - this uses O_CREAT|O_EXCL on POSIX
  await tempFile!.create(exclusive: true);

  // Verify restrictive permissions were established at creation (respecting umask).
  // We do NOT use chmod - the file must be created with correct permissions from the start.
  // On POSIX, the resulting mode is (0666 & ~umask). With default umask 0022, this gives 0644.
  // We require the file to have no group/other permissions (i.e., mode & 0o077 == 0).
  if (Platform.isLinux || Platform.isMacOS) {
    final stat = await tempFile.stat();
    final perms = stat.mode & _kPermMask; // 0o777
    // Fail closed if group or other has any permissions
    if ((perms & _kNoGroupOtherPerms) != 0) {
      await tempFile.delete();
      throw StateError(
        'Temporary file created with insecure permissions (mode: ${perms.toRadixString(8)}). '
        'Process umask must be restrictive (e.g., 0077) to create 0600 files.',
      );
    }
    // Additional check: owner must have read/write
    if ((perms & _kOwnerRWPerms) != _kOwnerRWPerms) {
      await tempFile.delete();
      throw StateError(
        'Temporary file created without owner read/write permissions (mode: ${perms.toRadixString(8)})',
      );
    }
  }
  return tempFile;
}

/// Opens the destination directory with O_DIRECTORY|O_NOFOLLOW and
/// translates kernel failures into honest StateErrors (missing vs symlinked
/// vs unknowable).
int _openDestDirNoFollow(String dirPath) {
  try {
    return PosixFs.openDirNoFollow(dirPath);
  } on PosixFsError catch (e) {
    if (e.errno == errnoEnoent) {
      throw StateError('Destination directory does not exist: $dirPath');
    }
    if (e.errno == errnoEloop) {
      throw StateError(
        'Destination directory is a symbolic link, refusing to write: $dirPath',
      );
    }
    throw StateError(
      'Destination directory is inaccessible and state could not be established: $dirPath ($e).',
    );
  }
}

/// Atomically writes [data] to [destination] using a secure temporary file.
///
/// Guarantees (Linux, the release platform — full POSIX pipeline):
///   * destination classification is independent of `exists()`: VALID and
///     BROKEN symlinks are refused through fstatat
///     (AT_SYMLINK_NOFOLLOW), directories and special files are refused;
///   * a missing destination is the distinct expected case and the commit
///     uses RENAME_NOREPLACE (a fresh destination cannot be overwritten by a
///     racing entry swap);
///   * an existing regular destination is replaced by renameat which never
///     FOLLOWS a symlink destination — it swaps the entry atomically;
///   * the temporary file is created by openat(O_CREAT|O_EXCL) with mode 0600
///     AT CREATION (umask cannot add bits), anchored to the pinned directory
///     descriptor — NO path components beyond the pinned descriptor are ever
///     resolved;
///   * content is written and verified through the descriptor, then fsynced
///     before the commit, and the directory is fsynced after it;
///   * the destination state is RECHECKED with fstatat immediately before the
///     commit rename — closing the validate→use window that path prechecks
///     alone can never close;
///   * pre-commit failures (write, fsync, verification, recheck) leave the
///     destination UNALTERED;
///   * post-commit failures (directory fsync, final stat) mean the new file
///     MAY be visible but crash durability is uncertain — the old destination
///     is NOT restored (that would require a second atomic operation).
///
/// Returns an [AtomicWriteResult] that distinguishes:
///   - pre-commit failures (destination unchanged)
///   - post-commit failures (destination may be visible but not durable)
///   - success (committed and verified)
///
/// Non-Linux platforms use the portable dart:io pipeline with the symlink
/// check unconditional of `exists()`; the dart:io "notFound" ambiguity and
/// the non-descriptor commit are documented platform limitations.
Future<AtomicWriteResult> atomicWrite(
  File destination,
  String data, {

  /// Used only by deterministic rollback regression tests.  It models a
  /// failure before a rollback write can commit, and is intentionally an
  /// explicit call-site parameter so it cannot accidentally affect the
  /// preceding import write.
  bool injectPreCommitFailure = false,
}) async {
  if (!destination.isAbsolute) {
    throw ArgumentError(
      'atomicWrite requires an absolute destination path: ${destination.path}',
    );
  }
  final parentPath = _lexicalNormalize(_parentOf(destination.path));
  final destBase = _basenameOf(destination.path);

  if (Platform.isLinux && !PosixFs.available) {
    return AtomicWriteResult.preCommitFailure(
      'POSIX filesystem helper unavailable on Linux; refusing insecure '
      'portable fallback: ${PosixFs.loadError}',
    );
  }
  if (!Platform.isLinux) {
    // Portable fallback returns AtomicWriteResult
    return _atomicWritePortable(destination, data);
  }

  // Canonical parent directory check: the parent must be a real directory on
  // its own lexical path — symlinked ancestry is refused outright.
  final String parentCanonical;
  try {
    parentCanonical = PosixFs.resolveCanonical(parentPath);
  } on PosixFsError catch (e) {
    if (e.errno == errnoEnoent) {
      return AtomicWriteResult.preCommitFailure(
        'Destination directory does not exist: $parentPath',
      );
    }
    return AtomicWriteResult.preCommitFailure(
      'Cannot establish state of destination directory $parentPath: '
      '$e (${e.meaning}).',
    );
  }
  if (parentCanonical != parentPath) {
    return AtomicWriteResult.preCommitFailure(
      'Destination parent directory is a symlink, refusing to write.',
    );
  }

  int dirfd;
  try {
    dirfd = _openDestDirNoFollow(parentCanonical);
  } on StateError catch (e) {
    return AtomicWriteResult.preCommitFailure(e.message);
  }
  int tempFd = -1;
  String? tempBase;
  try {
    // No-follow destination classification that does NOT depend on exists().
    final initial = PosixFs.classifyChildNoFollow(dirfd, destBase);
    final bool replaceExisting;
    switch (initial) {
      case PosixPathClass.symlink:
        // Valid or broken — every symlink entry is refused.
        return AtomicWriteResult.preCommitFailure(
          'Destination is a symbolic link, refusing to overwrite.',
        );
      case PosixPathClass.directory:
        return AtomicWriteResult.preCommitFailure(
          'Destination is a directory, refusing to overwrite: ${destination.path}',
        );
      case PosixPathClass.special:
        return AtomicWriteResult.preCommitFailure(
          'Destination is not a regular file, refusing to overwrite: ${destination.path}',
        );
      case PosixPathClass.inaccessible:
        return AtomicWriteResult.preCommitFailure(
          'Cannot establish state of destination ${destination.path}; refusing to write.',
        );
      case PosixPathClass.missing:
        replaceExisting = false;
        break;
      case PosixPathClass.regularFile:
        replaceExisting = true;
        break;
    }

    // Create temp file anchored to the pinned directory descriptor.
    // Uses openat(O_CREAT|O_EXCL) with mode 0600 - no path components
    // beyond the pinned descriptor are ever resolved.
    final (fd, tempName) = PosixFs.mkstempAt(
      dirfd,
      _sanitizeTempPrefix(destBase),
    );
    tempFd = fd;
    tempBase = tempName;
    // Pass full path to hook for test verification
    StorageDebugHooks.afterTempCreation?.call('$parentCanonical/$tempName');

    // This tracks the irreversible rename boundary, rather than whether the
    // final outcome is verified success.  Once renameat succeeds the old temp
    // name may be reused by another process; unlinking it during post-commit
    // error cleanup could then delete an unrelated file.
    var renameCommitted = false;
    try {
      if (injectPreCommitFailure) {
        return AtomicWriteResult.preCommitFailure(
          'Injected pre-commit write failure.',
        );
      }
      final payload = utf8.encode(data);
      PosixFs.writeAllToFd(tempFd, payload);
      PosixFs.fsyncFd(tempFd);

      // Verify content through the descriptor (no path involved).
      PosixFs.rewindFd(tempFd);
      final readBack = PosixFs.readAllFromFd(tempFd, maxBytes: payload.length);
      var mismatch = readBack.length != payload.length;
      if (!mismatch) {
        for (var i = 0; i < payload.length; i++) {
          if (readBack[i] != payload[i]) {
            mismatch = true;
            break;
          }
        }
      }
      if (mismatch) {
        return AtomicWriteResult.preCommitFailure(
          'Atomic write verification failed: content mismatch',
        );
      }

      // Permissions are created 0600 by mkstempAt; verify through the fd and
      // fail closed if the filesystem did something unexpected.
      var st = PosixFs.statFd(tempFd);
      if (st.permissions != posixMode0600) {
        PosixFs.fchmodFd(tempFd, posixMode0600); // tightening only
        st = PosixFs.statFd(tempFd);
        if (st.permissions != posixMode0600) {
          return AtomicWriteResult.preCommitFailure(
            'Temporary file created with insecure permissions (mode: '
            '${st.permissions.toRadixString(8)}); refusing to commit.',
          );
        }
      }
      if (!st.isRegular) {
        return AtomicWriteResult.preCommitFailure(
          'Temporary path is not a regular file; refusing to commit.',
        );
      }

      // Race-simulation hook: tests swap directory entries here to prove the
      // recheck below closes the validate→use window.
      StorageDebugHooks.beforeCommit?.call(destination.path);

      // Use-time recheck against the PINNED directory — this is what makes
      // the commit safe, not the earlier classification.
      final recheck = PosixFs.classifyChildNoFollow(dirfd, destBase);
      switch (recheck) {
        case PosixPathClass.symlink:
          return AtomicWriteResult.preCommitFailure(
            'Destination is a symbolic link, refusing to overwrite.',
          );
        case PosixPathClass.inaccessible:
          return AtomicWriteResult.preCommitFailure(
            'Cannot establish state of destination ${destination.path}; refusing to write.',
          );
        case PosixPathClass.missing:
          // Fresh path absent: the expected state, commit=NOREPLACE gets it.
          // An EXISTING destination that vanished mid-write: replacing an
          // absence is safe and stays atomic.
          break;
        case PosixPathClass.regularFile:
          if (!replaceExisting) {
            // Fresh-destination race: an entry appeared under a name we
            // verified as missing. RENAME_NOREPLACE refuses it anyway; the
            // explicit refusal gives the precise message.
            return AtomicWriteResult.preCommitFailure(
              'Destination appeared during write, refusing to overwrite fresh destination: ${destination.path}',
            );
          }
          break;
        case PosixPathClass.directory:
        case PosixPathClass.special:
          return AtomicWriteResult.preCommitFailure(
            'Destination is no longer a regular file, refusing to overwrite: ${destination.path}',
          );
      }

      // Atomic commit
      PosixFs.renameCommit(dirfd, tempBase, destBase, replace: replaceExisting);
      renameCommitted = true;

      // Hook: after rename commit - useful for injecting post-commit failures
      StorageDebugHooks.afterRenameCommit?.call(destination.path);

      // Verify the destination *name*, not merely tempFd.  tempFd continues
      // to identify our inode after rename even if another writer replaces
      // destBase immediately afterwards.  fstatat(AT_SYMLINK_NOFOLLOW) under
      // the pinned parent lets us reject that false-success case.
      final committedStat = PosixFs.statFd(tempFd);
      final namedStat = PosixFs.statChildNoFollow(dirfd, destBase);
      if (namedStat == null ||
          !namedStat.isRegular ||
          namedStat.device != committedStat.device ||
          namedStat.inode != committedStat.inode) {
        return AtomicWriteResult.postCommitFailure(
          destination,
          'Destination pathname no longer refers to the committed inode '
          'after rename; another process may have replaced it.',
        );
      }

      // Persist the directory entry itself (crash of the *directory* update
      // after an fsynced file is otherwise possible).
      try {
        if (StorageDebugHooks.injectFsyncFailure) {
          StorageDebugHooks.injectFsyncFailure = false;
          throw PosixFsError('fsync(injected)', 'dirfd', errnoEio);
        }
        PosixFs.fsyncFd(dirfd);
      } on PosixFsError catch (e) {
        // Directory fsync failed: the rename succeeded but the directory
        // metadata may not be durable. The new file MAY be visible but
        // crash durability is uncertain. We do NOT attempt to unlink the
        // destination (that would require a second atomic operation and
        // could delete a replacement by another process).
        return AtomicWriteResult.postCommitFailure(
          destination,
          'Directory fsync failed after commit: $e (${e.meaning}). '
          'The new file may be visible but crash durability is uncertain.',
          durabilityUncertain: true,
        );
      }

      // The temp fd still references the committed inode. The identity check
      // above additionally proved that the destination name referred to it at
      // the post-rename verification boundary.
      final finalStat = PosixFs.statFd(tempFd);
      if (finalStat.permissions != posixMode0600) {
        PosixFs.fchmodFd(tempFd, posixMode0600); // tighten, then recheck
        final tightened = PosixFs.statFd(tempFd);
        if (tightened.permissions != posixMode0600) {
          // The rename has already committed.  Do not unlink by name here:
          // another process could have replaced that directory entry after
          // the commit, and deleting it would risk unrelated data loss.
          return AtomicWriteResult.postCommitFailure(
            destination,
            'Atomic write result has insecure permissions (mode: '
            '${tightened.permissions.toRadixString(8)})',
          );
        }
      }

      // Inject read-back verification failure for testing
      if (StorageDebugHooks.injectReadbackVerificationFailure) {
        StorageDebugHooks.injectReadbackVerificationFailure = false;
        return AtomicWriteResult.postCommitFailure(
          destination,
          'Injected read-back verification failure: content mismatch after commit.',
        );
      }

      return AtomicWriteResult.success(destination);
    } finally {
      // Cleanup: remove ONLY the temp entry, never the destination.
      if (!renameCommitted) {
        try {
          PosixFs.unlinkChild(dirfd, tempBase);
        } catch (_) {}
      }
      if (tempFd >= 0) {
        try {
          PosixFs.closeFd(tempFd);
        } catch (_) {}
        tempFd = -1;
      }
    }
  } finally {
    try {
      PosixFs.closeFd(dirfd);
    } catch (_) {}
  }
}

/// Removes the final path entry without following it. This is intended for
/// non-vault state such as encrypted logs: it avoids dart:io's `exists` then
/// `delete` path race, but deliberately does not claim cross-process locking.
///
/// Linux uses a pinned parent descriptor and unlinkat. On other platforms the
/// documented portable fallback remains best effort.
Future<void> deletePathEntryNoFollow(File file) async {
  if (!file.isAbsolute) {
    throw ArgumentError('deletePathEntryNoFollow requires an absolute path');
  }
  if (Platform.isLinux) {
    if (!PosixFs.available) {
      throw StateError(
        'POSIX filesystem helper unavailable on Linux; refusing insecure '
        'portable fallback: ${PosixFs.loadError}',
      );
    }
    final parentPath = _lexicalNormalize(_parentOf(file.path));
    final parentCanonical = PosixFs.resolveCanonical(parentPath);
    if (parentCanonical != parentPath) {
      throw StateError('Destination parent directory is a symbolic link.');
    }
    final dirfd = _openDestDirNoFollow(parentCanonical);
    try {
      PosixFs.unlinkChild(dirfd, _basenameOf(file.path));
    } finally {
      PosixFs.closeFd(dirfd);
    }
    return;
  }
  final type = await FileSystemEntity.type(file.path, followLinks: false);
  if (type != FileSystemEntityType.notFound) await file.delete();
}

/// Portable (non-Linux) atomic write: dart:io pipeline with no-follow
/// symlink classification applied independently of `exists()`.
Future<AtomicWriteResult> _atomicWritePortable(
  File destination,
  String data,
) async {
  final parentDir = destination.parent;
  if (!await parentDir.exists()) {
    return AtomicWriteResult.preCommitFailure(
      'Destination directory does not exist: ${parentDir.path}',
    );
  }
  if (await isSymlink(parentDir.path)) {
    return AtomicWriteResult.preCommitFailure(
      'Destination parent directory is a symlink, refusing to write.',
    );
  }

  // Destination classification is independent of exists(): a BROKEN symlink
  // makes exists() false but must be refused exactly like a valid one.
  final destType = await FileSystemEntity.type(
    destination.path,
    followLinks: false,
  );
  if (destType == FileSystemEntityType.link) {
    return AtomicWriteResult.preCommitFailure(
      'Destination is a symbolic link, refusing to overwrite.',
    );
  }
  if (destType == FileSystemEntityType.directory) {
    return AtomicWriteResult.preCommitFailure(
      'Destination is a directory, refusing to overwrite: ${destination.path}',
    );
  }
  if (destType != FileSystemEntityType.notFound &&
      destType != FileSystemEntityType.file) {
    return AtomicWriteResult.preCommitFailure(
      'Destination is not a regular file, refusing to overwrite: ${destination.path}',
    );
  }

  final tempFile = await _createSecureTempFile(destination);
  try {
    StorageDebugHooks.afterTempCreation?.call(tempFile.path);
    await tempFile.writeAsString(data, flush: true, mode: FileMode.write);
    // Validate written content
    final written = await tempFile.readAsString();
    if (written != data) {
      await tempFile.delete();
      return AtomicWriteResult.preCommitFailure(
        'Atomic write verification failed: content mismatch',
      );
    }
    // Permissions were verified at temp creation (fail closed there); on
    // POSIX rename receives the same inode, preserving the mode.
    StorageDebugHooks.beforeCommit?.call(destination.path);
    // Atomic rename on POSIX — same directory, same filesystem.
    await tempFile.rename(destination.path);
    return AtomicWriteResult.success(destination);
  } catch (e) {
    // Cleanup on any error - NEVER touch the destination file
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    return AtomicWriteResult.preCommitFailure(e.toString());
  }
}

// ---------------------------------------------------------------------------
// Vault blob validation
// ---------------------------------------------------------------------------

/// Persists public configuration and the encrypted local vault.
///
/// Secrets are never stored in [SharedPreferences]; only public preferences
/// and the already-encrypted vault blob touch the normal app directories.
class AppStorage {
  AppStorage._();

  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    // Proxy passwords never go to SharedPreferences. Reading the secure store
    // is best-effort here so keyring-less systems still boot; a missing
    // password means the proxy fails auth rather than silently going direct.
    //
    // The Flutter test runner has no platform plugins. An unserviced method
    // channel can leave this future pending forever inside testWidgets' fake
    // async zone, so tests must not touch the OS keyring at all.
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        _proxyPasswordCache = await _secure
            .read(key: 'proxy_password')
            .timeout(_keyringTimeout);
        _torUpstreamPasswordCache = await _secure
            .read(key: 'tor_upstream_password')
            .timeout(_keyringTimeout);
      } catch (_) {
        _proxyPasswordCache = null;
        _torUpstreamPasswordCache = null;
        _torUpstreamPasswordCache = null;
      }
    }
  }

  static SharedPreferences get prefs {
    final value = _prefs;
    if (value == null) {
      throw StateError('AppStorage.init() must be called before use.');
    }
    return value;
  }

  // ---- public configuration ----

  static String get network => prefs.getString('network') ?? 'mainnet';
  static Future<void> setNetwork(String value) =>
      prefs.setString('network', value);

  static String get rpc {
    final saved = prefs.getString('rpc');
    if (saved != null && saved.startsWith('https://')) return saved;
    return BnbNetworks.defaultRpcs[network] ??
        BnbNetworks.defaultRpcs['mainnet']!;
  }

  /// Public address of the last watch-only profile, if any. Never a secret.
  static String? get watchAddress => prefs.getString('watch_address');
  static Future<void> setWatchAddress(String? value) async {
    if (value == null || value.isEmpty) {
      await prefs.remove('watch_address');
    } else {
      await prefs.setString('watch_address', value);
    }
  }

  /// §9 Lite mode: static status icons and simple lists, no pulsing.
  static bool get liteMode => prefs.getBool('lite_mode') ?? false;
  static Future<void> setLiteMode(bool value) =>
      prefs.setBool('lite_mode', value);

  /// Theme mode: system (0), light (1), dark (2), amoled (3)
  static int get themeModeIndex => prefs.getInt('theme_mode') ?? 0;
  static Future<void> setThemeMode(int value) =>
      prefs.setInt('theme_mode', value);

  /// Locale code (e.g., 'en', 'fa', 'ar', 'zh', 'ru', 'es')
  static String get locale => prefs.getString('locale') ?? 'en';
  static Future<void> setLocale(String value) =>
      prefs.setString('locale', value);

  static Future<void> setRpc(String value) => prefs.setString('rpc', value);

  static List<RpcNode> get nodes {
    final raw = prefs.getString('nodes');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) RpcNode.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setNodes(List<RpcNode> nodes) =>
      prefs.setString('nodes', jsonEncode([for (final n in nodes) n.toJson()]));

  static List<TokenInfo> get customTokens {
    final raw = prefs.getString('tokens');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) TokenInfo.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setCustomTokens(List<TokenInfo> tokens) => prefs
      .setString('tokens', jsonEncode([for (final t in tokens) t.toJson()]));

  /// §3: built-in tokens can be hidden without deleting their metadata. Keys
  /// are `network:0xaddress` so the same contract on another chain is separate.
  static Set<String> get hiddenTokens => {
    ...?prefs.getStringList('hidden_tokens'),
  };

  static Future<void> setHiddenTokens(Iterable<String> keys) =>
      prefs.setStringList('hidden_tokens', keys.toList()..sort());

  static List<WalletProfile> get profiles {
    final raw = prefs.getString('profiles');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) WalletProfile.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setProfiles(List<WalletProfile> profiles) =>
      prefs.setString(
        'profiles',
        jsonEncode([for (final p in profiles) p.toJson()]),
      );

  // ---- local pending transactions (public chain facts only, never keys) ----

  static String? getPendingTxsJson() => prefs.getString('pending_txs');
  static Future<void> setPendingTxsJson(String value) =>
      prefs.setString('pending_txs', value);

  // ---- BscScan API key (secret, secure storage only) ----

  static Future<String?> getBscscanKey() =>
      _secure.read(key: 'bscscan_api_key');
  static Future<void> setBscscanKey(String value) =>
      _secure.write(key: 'bscscan_api_key', value: value);
  static Future<void> clearBscscanKey() =>
      _secure.delete(key: 'bscscan_api_key');

  // ---- vault path management (M3) ----

  static const String _vaultPathKey = 'vault_custom_path';

  /// Get the custom vault path if set, otherwise null (uses default).
  static String? getVaultPath() => prefs.getString(_vaultPathKey);

  /// Set a custom vault path. Returns true if changed.
  static Future<bool> setVaultPath(String? path) async {
    final current = getVaultPath();
    if (path == null || path.isEmpty) {
      if (current != null) {
        await prefs.remove(_vaultPathKey);
        return true;
      }
      return false;
    }
    if (current == path) return false;
    await prefs.setString(_vaultPathKey, path);
    return true;
  }

  /// Get the active vault file (custom path or default).
  static Future<File> vaultFile() async {
    final customPath = getVaultPath();
    if (customPath != null) {
      final file = File(customPath);
      await ensureParentDir(file);
      return file;
    }
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (Platform.isLinux) {
      // Refuse a symlinked data directory ancestry: the vault must live at
      // the path the app selected, not wherever a link chain lands.
      try {
        final canonical = PosixFs.resolveCanonical(dir.path);
        if (canonical != _lexicalNormalize(dir.path)) {
          throw StateError(
            'Data directory is a symlink, refusing to use: ${dir.path}',
          );
        }
      } on PosixFsError catch (e) {
        if (e.errno != errnoEnoent) {
          throw StateError(
            'Cannot establish state of data directory ${dir.path}: $e (${e.meaning}).',
          );
        }
      }
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final mode = await dir.stat();
      if (mode.type == FileSystemEntityType.directory) {
        final perms = mode.mode & _kPermMask;
        // Require directory to have no group/other permissions (700)
        if ((perms & _kNoGroupOtherPerms) != 0) {
          throw StateError(
            'Data directory created with insecure permissions (mode: ${perms.toRadixString(8)}). Process umask must be restrictive (e.g., 0077).',
          );
        }
      }
    }
    return File('${dir.path}/bnb-wallet-vault.bnb');
  }

  static Future<void> ensureParentDir(File file) async {
    final parent = file.parent;
    if (Platform.isLinux) {
      // Refuse symlinked ancestry BEFORE creating anything under it. A
      // missing leaf is fine (Err.realpath ENOENT); any other error fails
      // closed instead of writing to an unverified location.
      try {
        final canonical = PosixFs.resolveCanonical(parent.path);
        if (canonical != _lexicalNormalize(parent.path)) {
          throw StateError(
            'Parent directory is a symlink, refusing to process: ${parent.path}',
          );
        }
      } on PosixFsError catch (e) {
        if (e.errno != errnoEnoent) {
          throw StateError(
            'Cannot establish state of parent directory for ${file.path}: '
            '$e (${e.meaning}).',
          );
        }
      }
    }
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final mode = await parent.stat();
      if (mode.type == FileSystemEntityType.directory) {
        final perms = mode.mode & _kPermMask;
        if ((perms & _kNoGroupOtherPerms) != 0) {
          throw StateError(
            'Parent directory created with insecure permissions (mode: ${perms.toRadixString(8)}). Process umask must be restrictive (e.g., 0077).',
          );
        }
      }
    }
  }

  /// Returns the app's data directory (same as vault/receipts/logs).
  static Future<Directory> getDataDirectory() async {
    final dir = await getApplicationSupportDirectory();
    if (Platform.isLinux) {
      // Audit events may be started from a widget callback without awaiting
      // them.  dart:io's asynchronous directory metadata futures inherit
      // Flutter's fake-async test zone and can then remain pending while an
      // append owns the global storage mutex.  The hardened Linux storage
      // pipeline below is descriptor/FFI based and synchronous already, so
      // keep this small local metadata check in that same execution model.
      // This avoids leaving a queued audit write (and its lock) stranded.
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      // Refuse a symlinked data directory ancestry (see vaultFile()).
      try {
        final canonical = PosixFs.resolveCanonical(dir.path);
        if (canonical != _lexicalNormalize(dir.path)) {
          throw StateError(
            'Data directory is a symlink, refusing to use: ${dir.path}',
          );
        }
      } on PosixFsError catch (e) {
        if (e.errno != errnoEnoent) {
          throw StateError(
            'Cannot establish state of data directory ${dir.path}: $e (${e.meaning}).',
          );
        }
      }
    }
    if (Platform.isLinux) {
      final mode = dir.statSync();
      if (mode.type == FileSystemEntityType.directory) {
        final perms = mode.mode & _kPermMask;
        if ((perms & _kNoGroupOtherPerms) != 0) {
          throw StateError(
            'Data directory created with insecure permissions (mode: ${perms.toRadixString(8)}). Process umask must be restrictive (e.g., 0077).',
          );
        }
      }
      return dir;
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (Platform.isMacOS) {
      final mode = await dir.stat();
      if (mode.type == FileSystemEntityType.directory) {
        final perms = mode.mode & _kPermMask;
        if ((perms & _kNoGroupOtherPerms) != 0) {
          throw StateError(
            'Data directory created with insecure permissions (mode: ${perms.toRadixString(8)}). Process umask must be restrictive (e.g., 0077).',
          );
        }
      }
    }
    return dir;
  }

  static Future<bool> vaultExists() async {
    final file = await vaultFile();
    final cls = await classifyPathNoFollow(file.path);
    switch (cls) {
      case PosixPathClass.missing:
        return false;
      case PosixPathClass.regularFile:
        return true;
      case PosixPathClass.symlink:
        // A symlink entry occupies the vault path even when broken (and even
        // when exists() would answer false over it). The app must know a
        // vault LOCATION exists; every write path independently refuses to
        // follow or replace it.
        return true;
      case PosixPathClass.directory:
      case PosixPathClass.special:
        return true;
      case PosixPathClass.inaccessible:
        throw StateError(
          'Cannot establish state of the vault at ${file.path}; refusing to guess.',
        );
    }
  }

  /// Reads the active vault blob. Returns null ONLY for a clean missing
  /// vault; any other state (symlink, directory, special file, unreadable)
  /// throws [StateError] so callers can never mistake "cannot read" for
  /// "no vault" and proceed to write over it.
  static Future<String?> readVault() async {
    final file = await vaultFile();
    return readRegularFileNoFollow(
      file.path,
      maxBytes: _kMaxVaultBytes,
      tooLargeMessage: 'Vault is too large.',
    );
  }

  /// Atomic save: writes a temp file first, then renames it over the final
  /// path (atomic on POSIX). A crash can therefore never leave a half-written
  /// vault in place of the good one.
  /// Uses secure temporary file with restrictive permissions from creation.
  static Future<void> writeVault(String base64) async {
    final file = await vaultFile();
    final result = await atomicWrite(file, base64);
    result.getOrThrow();
  }

  static Future<void> deleteVault() async {
    final file = await vaultFile();
    if (Platform.isLinux && PosixFs.available) {
      // Unlink the vault Entries through a pinned directory descriptor — a
      // symlink at the path is removed as an entry, never followed.
      final dirfd = _openDestDirNoFollow(_lexicalNormalize(file.parent.path));
      try {
        PosixFs.unlinkChild(dirfd, _basenameOf(file.path));
        final tmpBase = '${_basenameOf(file.path)}.tmp';
        PosixFs.unlinkChild(dirfd, tmpBase);
      } finally {
        PosixFs.closeFd(dirfd);
      }
      return;
    }
    if (await file.exists()) await file.delete();
    final tmp = File('${file.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
  }

  /// Atomic save: writes a temp file first, then renames it over the final
  /// path (atomic on POSIX). A crash can therefore never leave a half-written
  /// vault in place of the good one.
  /// Uses secure temporary file with restrictive permissions from creation.
  static Future<void> writeVaultAtomic(String base64) async {
    final file = await vaultFile();
    final result = await atomicWrite(file, base64);
    result.getOrThrow();
  }

  // ---- encrypted local receipts (key from wallet + drawer, see receipt_store) ----

  static Future<File> _receiptsFile() async {
    final vault = await vaultFile();
    return File('${vault.parent.path}/bnb-wallet-receipts.bin');
  }

  static Future<String?> readReceipts() async {
    try {
      final file = await _receiptsFile();
      final content = await readRegularFileNoFollow(
        file.path,
        maxBytes: _kMaxVaultBytes,
      );
      return content;
    } catch (_) {
      // Receipts are a non-critical archive: any unreadable, unexpected
      // (symlink/directory/special) or missing state degrades to null.
      // The read itself is descriptor-pinned on Linux; nothing is followed.
      return null;
    }
  }

  /// Atomic save, same pattern as the vault: temp file, rename, owner-only.
  /// Uses secure temporary file with restrictive permissions from creation.
  static Future<void> writeReceiptsAtomic(String base64) async {
    final file = await _receiptsFile();
    final result = await atomicWrite(file, base64);
    result.getOrThrow();
  }

  /// Erases everything the app can reach: shredded vault, preferences,
  /// secure-storage items. Overwriting flash is best-effort only (wear
  /// levelling makes guarantees impossible) — crypto-erase (deleting the
  /// device-bound key) is the strong part: remaining ciphertext stays inert.
  ///
  /// Returns the items that could NOT be removed (empty = fully clean), so
  /// the UI can never claim success while something still exists on disk.
  /// Shreds (best effort) and unlinks the entry at [path] without ever
  /// following a symlink: symlinks/directories/special files are unlinked as
  /// entries; only a REGULAR file is overwritten in place first, and the
  /// overwrite goes through a pinned descriptor opened with O_NOFOLLOW.
  /// Returns true when the entry is provably gone afterwards.
  static Future<bool> _shredAndUnlink(String path) async {
    final isNative = Platform.isLinux && PosixFs.available;
    if (isNative) {
      final dirPath = _lexicalNormalize(_parentOf(path));
      final base = _basenameOf(path);
      int dirfd;
      try {
        dirfd = _openDestDirNoFollow(dirPath);
      } catch (_) {
        return false;
      }
      try {
        final cls = PosixFs.classifyChildNoFollow(dirfd, base);
        if (cls == PosixPathClass.missing) return true;
        if (cls == PosixPathClass.inaccessible) return false;
        if (cls != PosixPathClass.regularFile) {
          // Never follow, never shred through: drop the entry itself.
          try {
            PosixFs.unlinkChild(dirfd, base);
            return PosixFs.classifyChildNoFollow(dirfd, base) ==
                PosixPathClass.missing;
          } catch (_) {
            return false;
          }
        }
        try {
          final fd = PosixFs.openWriteNoFollow(dirfd, base);
          try {
            final stat = PosixFs.statFd(fd);
            // Best-effort shred with random bytes before unlink.
            final random = math.Random.secure();
            final junk = Uint8List.fromList(
              List<int>.generate(
                stat.size.clamp(0, _kMaxShredBytes),
                (_) => random.nextInt(256),
              ),
            );
            PosixFs.writeAllToFd(fd, junk);
            PosixFs.fsyncFd(fd);
          } finally {
            PosixFs.closeFd(fd);
          }
          PosixFs.unlinkChild(dirfd, base);
          return PosixFs.classifyChildNoFollow(dirfd, base) ==
              PosixPathClass.missing;
        } catch (_) {
          return false;
        }
      } finally {
        try {
          PosixFs.closeFd(dirfd);
        } catch (_) {}
      }
    }
    // Portable fallback (non-Linux): legacy path-based shred.
    try {
      final file = File(path);
      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.type == FileSystemEntityType.file) {
          final random = math.Random.secure();
          await file.writeAsBytes([
            for (var i = 0; i < stat.size; i++) random.nextInt(256),
          ], flush: true);
        }
        await file.delete();
      }
      return !await file.exists();
    } catch (_) {
      try {
        return !await File(path).exists();
      } catch (_) {
        return false;
      }
    }
  }

  static Future<List<String>> eraseAllData() async {
    final leftovers = <String>[];
    final vault = await vaultFile();
    final receipts = await _receiptsFile();
    for (final path in <String>[
      vault.path,
      '${vault.path}.tmp',
      receipts.path,
      '${receipts.path}.tmp',
    ]) {
      if (!await _shredAndUnlink(path)) {
        leftovers.add(path);
      }
    }
    // The locked drawer holds the same class of key as the keyring copy:
    // shred it too, and drop the in-memory memo so a restart starts clean.
    final drawer = await _drawerFile();
    if (!await _shredAndUnlink(drawer.path)) {
      leftovers.add(drawer.path);
    }
    _deviceSecretCache = null;
    lastDeviceSecretFromDrawer = false;
    // Preferences: clear every key the plugin holds, then remove the backing
    // file itself — "erase everything" must leave no readable state behind.
    try {
      await prefs.clear();
    } catch (_) {}
    try {
      final prefsFile = File(
        '${(await getApplicationSupportDirectory()).path}'
        '/shared_preferences.json',
      );
      if (await prefsFile.exists()) await prefsFile.delete();
      if (await prefsFile.exists()) leftovers.add(prefsFile.path);
    } catch (_) {}
    for (final key in const [
      'network',
      'rpc',
      'nodes',
      'tokens',
      'profiles',
      'pending_txs',
      'auto_lock_seconds',
      'tor_enabled',
      'tor_host',
      'tor_port',
      'proxy_type',
      'proxy_host',
      'proxy_port',
      'proxy_user',
      'tor_bridge_type',
      'tor_bridge_lines',
      'strict_node',
      'node_warned',
      'token_user_sources',
      'hidden_tokens',
      'watch_address',
      'lite_mode',
    ]) {
      try {
        if (prefs.containsKey(key)) leftovers.add('preference "$key"');
      } catch (_) {}
    }
    _proxyPasswordCache = null;
    _torUpstreamPasswordCache = null;
    for (final task in [
      clearBscscanKey,
      clearPinHash,
      clearDeviceSecret,
      clearBackoffState,
      () => _secure.delete(key: 'proxy_password'),
      () => _secure.delete(key: 'tor_upstream_password'),
    ]) {
      try {
        await task();
      } catch (_) {}
    }
    return leftovers;
  }

  // ---- optional app lock PIN (Argon2id hash, never the PIN itself) ----

  static Future<String?> getPinHash() => _secure.read(key: 'app_lock_pin_hash');
  static Future<void> setPinHash(String value) =>
      _secure.write(key: 'app_lock_pin_hash', value: value);
  static Future<void> clearPinHash() =>
      _secure.delete(key: 'app_lock_pin_hash');

  // ---- device-bound secret (second vault key factor) ----

  /// Memoized handle: the store that owns the device secret is consulted at
  /// most ONCE per session. Repeating storage round-trips on every vault
  /// operation starved the window thread on weak Ubuntu systems (taste
  /// round 3: "Force Quit / Wait" freezes).
  static String? _deviceSecretCache;

  /// Set for the current call when the secret came from (or was written to)
  /// the locked drawer instead of the platform keyring. The app narrates
  /// this state once per session, in plain words.
  static bool lastDeviceSecretFromDrawer = false;

  /// Hard limit for one keyring round-trip. libsecret calls run on the
  /// window (GTK main) thread in the Linux plugin, so an unbounded wait
  /// there freezes the whole app.
  static const Duration _keyringTimeout = Duration(seconds: 3);

  /// Android/iOS first choice: Keystore/secure-store-backed secret — it
  /// behaves well there and nothing blocks a UI thread. Desktops (Linux,
  /// macOS, Windows) deliberately use the locked drawer INSTEAD of the
  /// keyring: the Linux secure-storage plugin runs libsecret synchronously
  /// inside the GTK window thread, which froze weak machines exactly when a
  /// fresh wallet was being stored. Machine binding is preserved either way
  /// (a copied vault stays inert without THIS machine's drawer/keyring).
  static bool get _keyringPreferred => Platform.isAndroid || Platform.isIOS;

  /// Reads (or creates once) the 32-byte device-bound secret.
  ///
  /// Safety rule (unchanged): if a vault already exists and its secret can
  /// neither be found anywhere nor migrated, the wallet FAILS CLOSED — it
  /// never mints a replacement that would lock the user out of their own
  /// vault.
  static Future<String> getOrGenerateDeviceSecret() async {
    final cached = _deviceSecretCache;
    if (cached != null) return cached;

    lastDeviceSecretFromDrawer = false;
    return _keyringPreferred ? _viaKeyring() : _viaDrawer();
  }

  /// Mobile path: platform keyring first, drawer as the emergency fallback,
  /// fail-closed when a vault depends on a stuck keyring.
  static Future<String> _viaKeyring() async {
    String? keyring;
    var keyringStuck = false;
    try {
      keyring = await _secure.read(key: _deviceKey).timeout(_keyringTimeout);
    } on Exception {
      keyringStuck = true;
    }
    if (keyring != null && keyring.isNotEmpty) {
      try {
        if (base64Decode(keyring).length == 32) {
          _deviceSecretCache = keyring;
          return keyring;
        }
      } on FormatException {
        // Broken record — treat like an empty keyring slot.
      }
    }

    String? drawer;
    try {
      drawer = await _readDrawerSecret();
    } on Exception {
      drawer = null;
    }
    if (drawer != null) {
      _deviceSecretCache = drawer;
      lastDeviceSecretFromDrawer = true;
      return drawer;
    }

    // Nothing readable anywhere yet. A stuck keyring is only fatal when a
    // vault already depends on its secret living inside the keyring — in
    // that case retry once, then fail closed. Minting here would lock the
    // user out of their own vault forever.
    if (keyringStuck && await vaultExists()) {
      try {
        final retry = await _secure
            .read(key: _deviceKey)
            .timeout(_keyringTimeout);
        if (retry != null && retry.isNotEmpty) {
          if (base64Decode(retry).length == 32) {
            _deviceSecretCache = retry;
            return retry;
          }
        }
      } on Exception {
        // Still stuck — fall through to fail closed.
      }
      throw const DeviceKeyException('Device key unavailable.');
    }

    // Fresh situation (no vault, or keyring alive but empty): mint a new
    // secret. Prefer the keyring; if its write hangs or is refused, keep
    // the secret in the locked drawer instead of freezing the app.
    final encoded = base64Encode(_osRandom32());
    try {
      await _secure
          .write(key: _deviceKey, value: encoded)
          .timeout(_keyringTimeout);
      _deviceSecretCache = encoded;
      return encoded;
    } on Exception {
      lastDeviceSecretFromDrawer = true;
      try {
        final stored = await _writeDrawerSecret(encoded);
        _deviceSecretCache = stored;
        return stored;
      } on Exception {
        throw const DeviceKeyException('Device key unavailable.');
      }
    }
  }

  /// Desktop path: the locked drawer is the primary home. The keyring is
  /// touched exactly once in the wallet's life — to migrate a pre-existing
  /// vault's key out of it — never on the wallet-creation hot path.
  static Future<String> _viaDrawer() async {
    // Drawer first: instant, nothing native involved.
    String? drawer;
    try {
      drawer = await _readDrawerSecret();
    } on Exception {
      drawer = null;
    }
    if (drawer != null) {
      _deviceSecretCache = drawer;
      lastDeviceSecretFromDrawer = true;
      return drawer;
    }

    // No drawer yet. If an older vault exists, its device key may still
    // live in the platform keyring — migrate it ONCE, then never come back.
    if (await vaultExists()) {
      String? migrated;
      try {
        migrated = await _secure.read(key: _deviceKey).timeout(_keyringTimeout);
      } on Exception {
        migrated = null;
      }
      if (migrated != null && migrated.isNotEmpty) {
        var valid = false;
        try {
          valid = base64Decode(migrated).length == 32;
        } on FormatException {
          valid = false;
        }
        if (valid) {
          try {
            final stored = await _writeDrawerSecret(migrated);
            _deviceSecretCache = stored;
            lastDeviceSecretFromDrawer = true;
            return stored;
          } on Exception {
            // Drawer unwritable: keep the keyring-backed value rather than
            // failing — the session still works (memoized, one keyring hit).
            _deviceSecretCache = migrated;
            return migrated;
          }
        }
      }
      // Keyring stuck or unreadable while a vault depends on it: ONE retry,
      // then fail closed. Minting a replacement here would orphan the vault.
      try {
        final retry = await _secure
            .read(key: _deviceKey)
            .timeout(_keyringTimeout);
        if (retry != null && retry.isNotEmpty) {
          var valid = false;
          try {
            valid = base64Decode(retry).length == 32;
          } on FormatException {
            valid = false;
          }
          if (valid) {
            try {
              final stored = await _writeDrawerSecret(retry);
              _deviceSecretCache = stored;
              lastDeviceSecretFromDrawer = true;
              return stored;
            } on Exception {
              _deviceSecretCache = retry;
              return retry;
            }
          }
        }
      } on Exception {
        // Still stuck — fail closed below.
      }
      throw const DeviceKeyException('Device key unavailable.');
    }

    // Fresh machine, no vault: mint straight into the drawer. The keyring
    // is never asked for anything — wallet creation cannot freeze.
    final encoded = base64Encode(_osRandom32());
    try {
      final stored = await _writeDrawerSecret(encoded);
      _deviceSecretCache = stored;
      lastDeviceSecretFromDrawer = true;
      return stored;
    } on Exception {
      throw const DeviceKeyException('Device key unavailable.');
    }
  }

  /// The locked drawer: same directory as the vault file, owner-only.
  /// Drops the in-memory device-secret memo so the next getter call touches
  /// the keyring/drawer again. Used by erase flows and by tests that need a
  /// cold start (the memo is process-wide).
  static void resetDeviceSecretMemo() {
    _deviceSecretCache = null;
    lastDeviceSecretFromDrawer = false;
  }

  static Future<File> _drawerFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/device_secret_v2.drawer');
    // Written through atomicWrite (mkstemp 0600 at creation + atomic rename).
    // Permissions are verified by the write pipeline itself, fail closed.
    return file;
  }

  static Future<String?> _readDrawerSecret() async {
    final file = await _drawerFile();
    final text = await readRegularFileNoFollow(
      file.path,
      maxBytes: _kMaxVaultBytes,
      symlinkMessage:
          'Device secret drawer is a symbolic link, refusing to read: ${file.path}',
      notRegularMessage:
          'Device secret drawer is not a regular file: ${file.path}',
    );
    if (text == null) return null; // clean missing drawer
    final trimmed = text.trim();
    try {
      if (base64Decode(trimmed).length != 32) return null;
    } on FormatException {
      return null;
    }
    return trimmed;
  }

  static Future<String> _writeDrawerSecret(String encoded) async {
    final file = await _drawerFile();
    // Replaces the former in-place writeAsString: the drawer now goes through
    // the same mkstemp-0600-at-creation + rename commit pipeline as the vault
    // (no-FOLLOW destination refusal, pinned recheck, atomic replacement).
    final result = await atomicWrite(file, encoded);
    if (result.state != AtomicWriteState.committedVerified) {
      throw StateError('Drawer write failed: ${result.error}');
    }
    if (result.destination?.path != file.path) {
      throw StateError('Drawer write verification failed.');
    }
    return encoded;
  }

  /// 32 bytes from the OS CSPRNG. Never time-based, never reused.
  static Uint8List _osRandom32() {
    final random = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
  }

  static Future<void> clearDeviceSecret() => _secure.delete(key: _deviceKey);

  static Future<bool> deviceKeyExists() async {
    try {
      final v = await _secure.read(key: _deviceKey);
      return v != null && v.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  // ---- failed-unlock backoff ----

  static Future<void> setBackoffState(int count, int untilEpochMs) =>
      _secure.write(key: _backoffKey, value: '$count:$untilEpochMs');
  static Future<(int, int)?> getBackoffState() async {
    final raw = await _secure.read(key: _backoffKey);
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final count = int.tryParse(parts[0]);
    final until = int.tryParse(parts[1]);
    if (count == null || until == null) return null;
    return (count, until);
  }

  static Future<void> clearBackoffState() => _secure.delete(key: _backoffKey);

  // ---- auto-lock + privacy preferences ----

  static int get autoLockSeconds => prefs.getInt('auto_lock_seconds') ?? 60;
  static Future<void> setAutoLockSeconds(int seconds) =>
      prefs.setInt('auto_lock_seconds', seconds);

  static bool get torEnabled => prefs.getBool('tor_enabled') ?? false;
  static Future<void> setTorEnabled(bool value) =>
      prefs.setBool('tor_enabled', value);
  static String get torHost => prefs.getString('tor_host') ?? '127.0.0.1';
  static Future<void> setTorHost(String value) =>
      prefs.setString('tor_host', value);
  static int get torPort => prefs.getInt('tor_port') ?? 9050;
  static Future<void> setTorPort(int value) => prefs.setInt('tor_port', value);

  // ---- global custom proxy (SOCKS5/SOCKS5h/HTTP CONNECT) ----

  static String? _proxyPasswordCache;
  static String? _torUpstreamPasswordCache;

  static ProxyType get proxyType {
    final raw = prefs.getString('proxy_type') ?? ProxyType.none.name;
    return ProxyType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => ProxyType.none,
    );
  }

  static String get proxyHost => prefs.getString('proxy_host') ?? '';
  static int get proxyPort => prefs.getInt('proxy_port') ?? 1080;
  static String? get proxyUser {
    final value = prefs.getString('proxy_user');
    return (value == null || value.isEmpty) ? null : value;
  }

  static String? get proxyPassword => _proxyPasswordCache;

  static GlobalProxyConfig get globalProxy => GlobalProxyConfig(
    type: proxyType,
    host: proxyHost,
    port: proxyPort,
    username: proxyUser,
    password: _proxyPasswordCache,
  );

  static Future<void> setGlobalProxy(GlobalProxyConfig config) async {
    await prefs.setString('proxy_type', config.type.name);
    await prefs.setString('proxy_host', config.host.trim());
    await prefs.setInt('proxy_port', config.port);
    final user = config.username?.trim() ?? '';
    if (user.isEmpty) {
      await prefs.remove('proxy_user');
    } else {
      await prefs.setString('proxy_user', user);
    }
    final pass = config.password ?? '';
    _proxyPasswordCache = pass.isEmpty ? null : pass;
    try {
      if (pass.isEmpty) {
        await _secure.delete(key: 'proxy_password');
      } else {
        await _secure.write(key: 'proxy_password', value: pass);
      }
    } catch (_) {
      // Session-only fallback: the password still works until this process
      // exits, and the UI warns that it was not stored persistently.
    }
  }

  static Future<void> clearProxy() =>
      setGlobalProxy(const GlobalProxyConfig.disabled());

  // ---- spending safety policy (not secrets) ----

  static bool get spendingFrozen => prefs.getBool('spending_frozen') ?? false;

  static Future<void> setSpendingFrozen(bool value) =>
      prefs.setBool('spending_frozen', value);

  static BigInt get spendingMaxPerTxWei {
    final raw = prefs.getString('spending_max_per_tx_wei') ?? '0';
    return BigInt.tryParse(raw) ?? BigInt.zero;
  }

  static Future<void> setSpendingMaxPerTxWei(BigInt value) =>
      prefs.setString('spending_max_per_tx_wei', value.toString());

  static List<String> get spendingAllowlist {
    final raw = prefs.getString('spending_allowlist');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final value in decoded)
          if ('$value'.trim().isNotEmpty) '$value'.trim().toLowerCase(),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setSpendingAllowlist(List<String> values) {
    final unique = <String>{
      for (final value in values)
        if (value.trim().isNotEmpty) value.trim().toLowerCase(),
    }.toList()..sort();
    return prefs.setString('spending_allowlist', jsonEncode(unique));
  }

  // ---- managed Tor bridge preferences (not secrets) ----

  static TorBridgeType get torBridgeType {
    final raw = prefs.getString('tor_bridge_type') ?? TorBridgeType.none.name;
    return TorBridgeType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => TorBridgeType.none,
    );
  }

  static List<String> get torBridgeLines {
    final raw = prefs.getString('tor_bridge_lines');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final line in decoded) '$line'];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setTorBridge(
    TorBridgeType type,
    List<String> lines,
  ) async {
    await prefs.setString('tor_bridge_type', type.name);
    await prefs.setString('tor_bridge_lines', jsonEncode(lines));
  }

  // ---- managed Tor upstream proxy and chain depth ----

  static ProxyType get torUpstreamType {
    final raw = prefs.getString('tor_upstream_type') ?? ProxyType.none.name;
    return ProxyType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => ProxyType.none,
    );
  }

  static String get torUpstreamHost =>
      prefs.getString('tor_upstream_host') ?? '';
  static int get torUpstreamPort => prefs.getInt('tor_upstream_port') ?? 1080;
  static String? get torUpstreamUser {
    final value = prefs.getString('tor_upstream_user');
    return (value == null || value.isEmpty) ? null : value;
  }

  static String? get torUpstreamPassword => _torUpstreamPasswordCache;

  static GlobalProxyConfig get torUpstream => GlobalProxyConfig(
    type: torUpstreamType,
    host: torUpstreamHost,
    port: torUpstreamPort,
    username: torUpstreamUser,
    password: _torUpstreamPasswordCache,
  );

  static Future<void> setTorUpstream(GlobalProxyConfig config) async {
    await prefs.setString('tor_upstream_type', config.type.name);
    await prefs.setString('tor_upstream_host', config.host.trim());
    await prefs.setInt('tor_upstream_port', config.port);
    final user = config.username?.trim() ?? '';
    if (user.isEmpty) {
      await prefs.remove('tor_upstream_user');
    } else {
      await prefs.setString('tor_upstream_user', user);
    }
    final pass = config.password ?? '';
    _torUpstreamPasswordCache = pass.isEmpty ? null : pass;
    try {
      if (pass.isEmpty) {
        await _secure.delete(key: 'tor_upstream_password');
      } else {
        await _secure.write(key: 'tor_upstream_password', value: pass);
      }
    } catch (_) {
      // Session-only fallback; the UI warns that it was not stored.
    }
  }

  static Future<void> clearTorUpstream() =>
      setTorUpstream(const GlobalProxyConfig.disabled());

  static int get torChainDepth =>
      (prefs.getInt('tor_chain_depth') ?? 1).clamp(1, 3);

  static Future<void> setTorChainDepth(int value) =>
      prefs.setInt('tor_chain_depth', value.clamp(1, 3));

  /// "Use only my node" (§10d strict mode): the wallet talks to the selected
  /// door ONLY — no built-in fallbacks, no other candidate, nothing else.
  static bool get strictNode => prefs.getBool('strict_node') ?? false;
  static Future<void> setStrictNode(bool value) =>
      prefs.setBool('strict_node', value);

  /// §10f Wallet mode: 0=hot (normal), 1=cold (offline signer), 2=online (watch-only companion).
  static int get walletModeIndex => prefs.getInt('wallet_mode') ?? 0;
  static Future<void> setWalletMode(int value) =>
      prefs.setInt('wallet_mode', value);

  /// URLs whose one-time "what a node sees" warning was already accepted.
  static List<String> get nodeWarnedUrls {
    final raw = prefs.getString('node_warned') ?? '';
    if (raw.isEmpty) return const [];
    try {
      return [for (final v in (jsonDecode(raw) as List)) v.toString()];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setNodeWarnedUrls(List<String> urls) =>
      prefs.setString('node_warned', jsonEncode(urls));

  // ---- trusted token-signing-list sources (§10e) ----

  /// The user's OWN trusted links (add/remove/reorder), kept separate from
  /// the shipped defaults so an update can never overwrite what the user
  /// decided to trust.
  static List<Map<String, String>> get userTokenSources {
    final raw = prefs.getString('token_user_sources') ?? '';
    if (raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            {'name': '${e['name'] ?? ''}', 'url': '${e['url'] ?? ''}'},
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setUserTokenSources(List<Map<String, String>> links) =>
      prefs.setString(
        'token_user_sources',
        jsonEncode([for (final l in links) l]),
      );

  /// One-time notice about what the source list is (and is not).
  static bool get tokenSourcesNoticeSeen =>
      prefs.getBool('token_sources_notice') ?? false;

  static Future<void> setTokenSourcesNoticeSeen() =>
      prefs.setBool('token_sources_notice', true);
}

/// The platform secure store could not serve its key. Never silently weakens.
class DeviceKeyException implements Exception {
  const DeviceKeyException(this.message);
  final String message;

  @override
  String toString() => message;
}

const String _deviceKey = 'device_secret_v2';
const String _backoffKey = 'app_lock_backoff';
