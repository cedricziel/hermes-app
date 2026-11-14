/// What the profile's `voice_chat` model slot resolves to, read from
/// `GET /api/model/auxiliary`. A call's turns run on that route
/// (`voice_turn`), so a profile where it resolves to nothing gets a warning.
enum VoiceModelRoute {
  /// The slot names a model.
  named,

  /// The slot follows the main model (provider `auto` or `main`, no model, no
  /// base URL) and the main model is set.
  followsMain,

  /// The slot pins a provider without a model: Hermes runs it on that
  /// provider's fast auxiliary model.
  providerOnly,

  /// The slot has nothing to run on.
  unresolved,

  /// The answer has no such slot, so nothing can be said.
  unknown;

  /// Whether Hermes has a model to run voice turns on.
  bool get resolved =>
      this == named || this == followsMain || this == providerOnly;

  /// Reads the body of the route, which has no response schema. A row that
  /// inherits another slot carries `effective`, the route it uses right now.
  factory VoiceModelRoute.fromJson(Object? body, {String task = 'voice_chat'}) {
    if (body is! Map) return unknown;
    final rows = body['tasks'];
    if (rows is! List) return unknown;
    Map<Object?, Object?>? row;
    for (final candidate in rows.whereType<Map<Object?, Object?>>()) {
      if (candidate['task'] == task) row = candidate;
    }
    if (row == null) return unknown;
    final effective = row['effective'];
    final route = effective is Map ? effective : row;
    final provider = _text(route['provider']).toLowerCase();
    final model = _text(route['model']);
    final baseUrl = _text(route['base_url']);
    if (model.isNotEmpty) return named;
    if (baseUrl.isNotEmpty) return unresolved;
    if (provider.isEmpty || provider == 'auto' || provider == 'main') {
      final main = body['main'];
      return main is Map && _text(main['model']).isNotEmpty
          ? followsMain
          : unresolved;
    }
    return providerOnly;
  }

  static String _text(Object? value) => value is String ? value.trim() : '';
}
