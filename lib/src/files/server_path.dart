/// How a [ServerPath] is written, which decides its separators and its root.
enum ServerPathStyle {
  /// `/srv/project`
  posix,

  /// `C:\Users\me` (a forward slash also separates)
  windowsDrive,

  /// `\\server\share\folder`
  unc,
}

/// An absolute path on the Hermes server, exactly as the server wrote it.
///
/// The value wraps that text and never rewrites it: [value] is what goes back
/// into a request, so the client cannot change which file is meant. It offers
/// only what the Files page needs to move around: [segments], [parent],
/// [name] and [isWithin], which compares whole path components and never
/// text prefixes (`/srv/app-secrets` is not within `/srv/app`).
///
/// There is deliberately no `join`: every child path comes from a listing the
/// server answered. A path with a `.` or `..` component, a NUL, or no root is
/// refused by [tryParse] instead of being tidied up, because tidying could
/// point somewhere else than the server meant.
///
/// [toString] never prints the path, so one interpolated into a log line or
/// an exception message leaks nothing; read [value] to send it.
class ServerPath {
  const ServerPath._(
    this.value,
    this.style,
    this._root,
    this._rootKey,
    this._segments,
    this._ends,
  );

  /// Reads [text] as an absolute POSIX, Windows drive or UNC path, or returns
  /// null when it is not one.
  static ServerPath? tryParse(String text) {
    if (text.isEmpty || text.contains('\u0000')) return null;

    final ServerPathStyle style;
    final int rootEnd;
    final String rootKey;
    if (text.startsWith(r'\\')) {
      final parts = _uncRoot(text);
      if (parts == null) return null;
      style = ServerPathStyle.unc;
      rootEnd = parts.end;
      rootKey = parts.key;
    } else if (text.length >= 3 &&
        _isDriveLetter(text.codeUnitAt(0)) &&
        text[1] == ':' &&
        (text[2] == r'\' || text[2] == '/')) {
      style = ServerPathStyle.windowsDrive;
      rootEnd = 3;
      rootKey = '${text[0].toLowerCase()}:';
    } else if (text.startsWith('/')) {
      style = ServerPathStyle.posix;
      rootEnd = 1;
      rootKey = '/';
    } else {
      return null;
    }

    final slashes = style == ServerPathStyle.posix;
    final segments = <String>[];
    final ends = <int>[];
    var start = rootEnd;
    void take(int end) {
      if (end > start) {
        final segment = text.substring(start, end);
        if (segment == '.' || segment == '..') return;
        segments.add(segment);
        ends.add(end);
      }
    }

    for (var i = rootEnd; i <= text.length; i++) {
      final atEnd = i == text.length;
      final unit = atEnd ? 0 : text.codeUnitAt(i);
      final separator = !atEnd && (unit == 0x2F || (!slashes && unit == 0x5C));
      if (atEnd || separator) {
        final before = segments.length;
        take(i);
        // `.` and `..` are refused rather than skipped.
        if (i > start && segments.length == before) return null;
        start = i + 1;
      }
    }
    return ServerPath._(
      text,
      style,
      text.substring(0, rootEnd),
      rootKey,
      List.unmodifiable(segments),
      List.unmodifiable(ends),
    );
  }

  static bool _isDriveLetter(int unit) =>
      (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);

  /// `\\server\share`: both parts are needed to name anything. Either
  /// separator ends a part, a `.`, `..` or `?` part is refused (so are the
  /// `\\?\` and `\\.\` device forms), and the share name must not be one.
  static ({int end, String key})? _uncRoot(String text) {
    int nextSeparator(int from) {
      for (var i = from; i < text.length; i++) {
        final unit = text.codeUnitAt(i);
        if (unit == 0x5C || unit == 0x2F) return i;
      }
      return text.length;
    }

    bool refused(String part) => part == '.' || part == '..' || part == '?';

    final serverEnd = nextSeparator(2);
    if (serverEnd <= 2 || serverEnd >= text.length) return null;
    final shareStart = serverEnd + 1;
    final shareEnd = nextSeparator(shareStart);
    if (shareEnd <= shareStart) return null;
    final server = text.substring(2, serverEnd);
    final share = text.substring(shareStart, shareEnd);
    if (refused(server) || refused(share)) return null;
    final key = '${server.toLowerCase()}\\${share.toLowerCase()}';
    return (end: shareEnd, key: key);
  }

  /// The path as the server wrote it, for a request. Never rewritten.
  final String value;
  final ServerPathStyle style;
  final String _root;
  final String _rootKey;
  final List<String> _segments;
  final List<int> _ends;

  /// The components below the root, in order. Empty for a root.
  List<String> get segments => _segments;

  /// The last component, or an empty string for a root.
  String get name => _segments.isEmpty ? '' : _segments.last;

  bool get isRoot => _segments.isEmpty;

  /// The folder that holds this one, cut from the same text, or null at a
  /// root.
  ServerPath? get parent {
    if (isRoot) return null;
    final cut = _segments.length == 1
        ? _root
        : value.substring(0, _ends[_segments.length - 2]);
    return tryParse(cut);
  }

  /// Whether this path is [root] or lies below it, by whole components.
  ///
  /// Drive letters and UNC server and share names compare without regard to
  /// case, since Windows does; every other component is compared exactly, so
  /// a difference in case reads as outside rather than risk reading a
  /// different file as the same one.
  bool isWithin(ServerPath root) {
    if (style != root.style || _rootKey != root._rootKey) return false;
    if (root._segments.length > _segments.length) return false;
    for (var i = 0; i < root._segments.length; i++) {
      if (_segments[i] != root._segments[i]) return false;
    }
    return true;
  }

  /// Equal when the server wrote the same text. `/srv/app/` and `/srv/app`
  /// are different values that [isWithin] treats as the same folder.
  @override
  bool operator ==(Object other) => other is ServerPath && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ServerPath(<${style.name}, ${_segments.length}>)';
}
