import 'attention.dart';

/// What the account button and the Mac sidebar's Server row show about the
/// server, beside its name. The mark never relies on colour: a word or an
/// accessible label always says the same.
enum ServerAttentionMark {
  none,
  needsAttention,
  updating,
  restarting;

  /// An update in progress outranks a restart, which outranks a problem.
  static ServerAttentionMark of({
    Attention? attention,
    bool updating = false,
    bool restarting = false,
  }) {
    if (updating) return ServerAttentionMark.updating;
    if (restarting) return ServerAttentionMark.restarting;
    return attention?.needsAttention ?? false ? needsAttention : none;
  }

  /// Whether the warning dot is drawn on the avatar and the menu row.
  bool get showsDot => this == needsAttention;
}
