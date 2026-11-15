import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:qr/qr.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/motion_spinner.dart';
import 'pairing_buttons.dart';

/// The side of the code's tile on a phone and in a stacked layout, in points.
/// The code and its quiet zone are inside it: the tile does not scale with
/// the text size, because a scanner needs the contrast and the quiet zone, not
/// large text.
const kQrTileSize = 240.0;

/// The side of the tile in the two-column layout.
const kQrTileSizeWide = 280.0;

/// The quiet zone around the code, in modules. The QR standard asks for four.
/// The renderer derives the module size from the payload, so this holds
/// whatever the payload's size.
const kQrQuietModules = 4;

/// The last stretch of the setup, in which the countdown is a warning.
const kQrExpiringWindow = Duration(seconds: 60);

/// The left time at which the countdown is announced to a screen reader.
const kQrAnnounceAt = [60, 30, 10];

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// Whether the code may be drawn.
enum QrCodeVisibility {
  /// Draw it.
  shown,

  /// Allowed, but the user taps "Show QR code" first (a handset).
  needsTap,

  /// The app is not in front, App Lock is locked or a computer's window has no
  /// focus: "Hidden", and it returns by itself.
  hidden,
}

/// The dark and light modules of one QR code. It prints as a fixed string.
@immutable
final class QrMatrix {
  const QrMatrix._(this.count, this._dark);

  /// The modules along one side.
  final int count;
  final Uint8List _dark;

  /// Encodes [payload] at the lowest error correction (a code on a screen
  /// does not get scratched, and fewer modules are larger ones), or null when
  /// it is too long for any QR code.
  static QrMatrix? encode(String payload) {
    try {
      final image = QrImage(
        QrCode(
          payload: QrPayload.fromString(payload),
          errorCorrectLevel: QrErrorCorrectLevel.low,
        ),
      );
      final count = image.moduleCount;
      final dark = Uint8List(count * count);
      for (var r = 0; r < count; r++) {
        for (var c = 0; c < count; c++) {
          if (image.isDark(r, c)) dark[r * count + c] = 1;
        }
      }
      return QrMatrix._(count, dark);
    } on InputTooLongException {
      return null;
    }
  }

  bool isDark(int row, int col) => _dark[row * count + col] == 1;

  @override
  String toString() => 'QrMatrix(…)';
}

/// Draws a [QrMatrix] black on white with a quiet zone of
/// [kQrQuietModules] modules on every side, in a square of [size] points. The
/// colours are fixed: they never follow the theme. Module edges are rounded to
/// device pixels, so neighbours share an edge exactly and no hairline shows
/// between them. No semantics of its own: [QrCodeTile] labels it.
class QrCodePattern extends StatelessWidget {
  const QrCodePattern({super.key, required this.matrix, required this.size});

  final QrMatrix matrix;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _QrPainter(matrix, MediaQuery.devicePixelRatioOf(context)),
  );
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.matrix, this.pixelRatio);

  final QrMatrix matrix;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final n = matrix.count;
    final module = size.width / (n + 2 * kQrQuietModules);
    double edge(int i) =>
        (i * module * pixelRatio).roundToDouble() / pixelRatio;
    canvas.drawRect(Offset.zero & size, Paint()..color = _white);
    final paint = Paint()
      ..color = _black
      ..isAntiAlias = false;
    for (var r = 0; r < n; r++) {
      var c = 0;
      while (c < n) {
        if (!matrix.isDark(r, c)) {
          c++;
          continue;
        }
        final start = c;
        while (c < n && matrix.isDark(r, c)) {
          c++;
        }
        canvas.drawRect(
          Rect.fromLTRB(
            edge(start + kQrQuietModules),
            edge(r + kQrQuietModules),
            edge(c + kQrQuietModules),
            edge(r + kQrQuietModules + 1),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      !identical(old.matrix, matrix) || old.pixelRatio != pixelRatio;
}

/// The square that holds the code, or stands in its place.
///
/// Shown, it is a fixed [size] tile, white with black modules in light and
/// dark alike and a 1 pt outline, so its edge shows on the white page. Hidden
/// or waiting for a tap, no code is built at all: the tile keeps its footprint
/// (it only grows taller when the text is large) and says "Hidden", with
/// "Show QR code" on a handset ([QrCodeVisibility.needsTap]) or the line
/// "Shows again when the app is unlocked and in front." on a tablet or a
/// computer ([QrCodeVisibility.hidden]).
///
/// The [payload] is a credential: it is read only while [visibility] is
/// [QrCodeVisibility.shown] (the constructor drops it otherwise), appears in
/// no label, tooltip, key or `toString`, and is never offered for copying. The
/// whole tile is one accessibility node: "QR code to scan with WhatsApp" or
/// "QR code hidden", and in the second case "Show QR code" is the only target.
class QrCodeTile extends StatefulWidget {
  const QrCodeTile({
    super.key,
    required this.visibility,
    String? payload,
    this.onShow,
    this.size = kQrTileSize,
  }) : payload = visibility == QrCodeVisibility.shown ? payload : null,
       assert(
         visibility != QrCodeVisibility.shown || payload != null,
         'A shown tile needs the payload.',
       );

  final QrCodeVisibility visibility;

  /// The text the code encodes; null unless shown.
  final String? payload;
  final VoidCallback? onShow;
  final double size;

  @override
  State<QrCodeTile> createState() => _QrCodeTileState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<QrCodeVisibility>('visibility', visibility));
  }
}

class _QrCodeTileState extends State<QrCodeTile> {
  QrMatrix? _matrix;

  @override
  void initState() {
    super.initState();
    _encode();
  }

  @override
  void didUpdateWidget(QrCodeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload != widget.payload) _encode();
  }

  void _encode() {
    final payload = widget.payload;
    _matrix = payload == null ? null : QrMatrix.encode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final outline = Border.all(color: scheme.outline);
    final radius = BorderRadius.circular(8);
    if (widget.visibility == QrCodeVisibility.shown) {
      final matrix = _matrix;
      if (matrix != null) {
        return Semantics(
          label: l10n.messagingWhatsappQrLabel,
          image: true,
          excludeSemantics: true,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: _white, borderRadius: radius),
            foregroundDecoration: BoxDecoration(
              border: outline,
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: QrCodePattern(matrix: matrix, size: widget.size),
            ),
          ),
        );
      }
    }
    final muted = context.hermesColors.subtleText;
    final tooLong = widget.visibility == QrCodeVisibility.shown;
    final tap = widget.visibility == QrCodeVisibility.needsTap;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    // Align loosens the parent's constraints, so the tile is its own size
    // (and taller only when the text needs it) inside a tight box too.
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.size,
          // At a large text size the stand-in takes the room it is given, so
          // its words do not break inside a word. It is not a scan target.
          maxWidth: largeText ? double.infinity : widget.size,
          minHeight: widget.size,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: outline,
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              heightFactor: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Semantics(
                    label: l10n.messagingWhatsappQrHiddenLabel,
                    container: true,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          AppIcon(AppIcons.eyeOff, size: 32, color: muted),
                          Text(
                            tooLong
                                ? l10n.messagingWhatsappQrCannotDraw
                                : l10n.messagingWhatsappQrHidden,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (tap)
                    PairingButton.filled(
                      label: l10n.messagingWhatsappShowQr,
                      onPressed: widget.onShow,
                    )
                  else if (!tooLong)
                    Text(
                      l10n.messagingWhatsappQrShowsAgain,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Waiting for a scan" (a spinner and the words, a polite live region) and
/// the setup's countdown under it: "Setup closes in 8:42". The countdown counts
/// the setup's ten minutes, not the code's rotation. In the last minute it is
/// a warning banner with the time left in its title. A screen reader gets it at
/// 60, 30 and 10 seconds left, never every second.
class QrScanStatus extends StatefulWidget {
  const QrScanStatus({super.key, this.timeLeft});

  /// The time until the server closes the setup; null shows no countdown.
  final Duration? timeLeft;

  @override
  State<QrScanStatus> createState() => _QrScanStatusState();
}

/// [time] as minutes and seconds: `8:42`.
String formatQrTimeLeft(Duration time) {
  final seconds = time.inSeconds.clamp(0, 86399);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _QrScanStatusState extends State<QrScanStatus> {
  @override
  void didUpdateWidget(QrScanStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.timeLeft?.inSeconds;
    final now = widget.timeLeft?.inSeconds;
    if (before == null || now == null) return;
    for (final mark in kQrAnnounceAt) {
      if (before > mark && now <= mark) {
        _announce(mark);
        return;
      }
    }
  }

  void _announce(int seconds) {
    final text = context.l10n.messagingWhatsappCountdownAnnounce(seconds);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        Directionality.of(context),
      ).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.hermesColors.subtleText;
    final left = widget.timeLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          label: l10n.messagingWhatsappWaitingForScan,
          child: ExcludeSemantics(
            child: Row(
              spacing: 10,
              children: [
                const MotionSpinner(),
                Expanded(child: Text(l10n.messagingWhatsappWaitingForScan)),
              ],
            ),
          ),
        ),
        if (left != null && left <= kQrExpiringWindow)
          AppBanner(
            tone: AppBannerTone.warning,
            title: l10n.messagingWhatsappCountdownExpiring(
              formatQrTimeLeft(left),
            ),
            detail: l10n.messagingWhatsappExpiringDetail,
          )
        else if (left != null)
          Text(
            l10n.messagingWhatsappCountdown(formatQrTimeLeft(left)),
            style: TextStyle(color: muted),
          ),
      ],
    );
  }
}

/// The code with its status lines, stacked: the tile, "Waiting for a scan"
/// and the countdown. The two-column layout places [QrCodeTile] and
/// [QrScanStatus] itself.
class QrCodeCard extends StatelessWidget {
  const QrCodeCard({
    super.key,
    required this.visibility,
    String? payload,
    this.timeLeft,
    this.onShow,
  }) : payload = visibility == QrCodeVisibility.shown ? payload : null;

  final QrCodeVisibility visibility;

  /// The text the code encodes; null unless [visibility] is shown.
  final String? payload;
  final Duration? timeLeft;
  final VoidCallback? onShow;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Center(
        child: QrCodeTile(
          visibility: visibility,
          payload: payload,
          onShow: onShow,
        ),
      ),
      QrScanStatus(timeLeft: timeLeft),
    ],
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<QrCodeVisibility>('visibility', visibility));
  }
}
