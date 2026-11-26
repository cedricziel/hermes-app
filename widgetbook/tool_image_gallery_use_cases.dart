import 'dart:convert';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_image_gallery.dart';
import 'package:hermes_app/src/chat/widgets/tool_image_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/image_tool_fixtures.dart';
import 'frame.dart';

/// A 1 x 1 PNG the loaded tiles stretch: the catalog has no network.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/'
  'iZk9HQAAAABJRU5ErkJggg==',
);

ImageProvider _picture(int _) => MemoryImage(_png);

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

Widget _media(Widget child, {double? scale, bool still = false}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: scale == null ? null : TextScaler.linear(scale),
      disableAnimations: still,
    ),
    child: child,
  ),
);

void _tap() {}

ToolImageTile _tile(
  ToolImageState state, {
  String alt = 'Front view of the blue backpack',
  String size = '800 × 800',
  String host = 'cdn.shop.example',
  double aspectRatio = 4 / 3,
}) => ToolImageTile(
  state: state,
  alt: alt,
  name: alt,
  size: size,
  host: host,
  aspectRatio: aspectRatio,
  image: state == ToolImageState.loaded ? _picture : null,
  onTap: state == ToolImageState.loading ? null : _tap,
);

List<ToolImageTile> _nine() => [
  _tile(ToolImageState.loaded),
  _tile(ToolImageState.idle, alt: 'Side view'),
  _tile(ToolImageState.failed, alt: 'Back view', host: 'img.cdn.example'),
  _tile(ToolImageState.insecure, alt: 'Logo', host: 'old.example'),
  _tile(ToolImageState.tooLarge, alt: 'Poster', size: '9000 × 6000'),
  _tile(ToolImageState.loading, alt: 'Detail of the zip'),
  _tile(ToolImageState.idle, alt: ''),
  _tile(ToolImageState.idle, alt: 'Strap'),
  _tile(ToolImageState.idle, alt: 'Box', size: ''),
];

Widget _gallery(
  List<ToolImageTile> tiles, {
  int hidden = 0,
  bool single = false,
  double width = 390,
}) => frame(
  ToolImageGallery(
    tiles: tiles,
    hidden: hidden,
    single: single,
    onLoadAll: tiles.any((t) => t.state == ToolImageState.idle) ? (_) {} : null,
  ),
  maxWidth: width,
);

Widget _card(ToolCall call, {double width = 480}) =>
    frame(ToolCallCard(call: call, initiallyOpen: true), maxWidth: width);

ToolCall _vision() => visionCall(visionAnswer());

WidgetbookNode toolImageGalleryNode() => WidgetbookFolder(
  name: 'Tool images',
  children: [
    WidgetbookComponent(
      name: 'ToolImageTile',
      useCases: [
        for (final state in ToolImageState.values)
          WidgetbookUseCase(
            name: state.name,
            builder: (_) => frame(
              _tile(
                state,
                aspectRatio: state == ToolImageState.generating
                    ? 16 / 9
                    : 4 / 3,
              ),
              maxWidth: 240,
            ),
          ),
        WidgetbookUseCase(
          name: 'no alt text',
          builder: (_) =>
              frame(_tile(ToolImageState.idle, alt: ''), maxWidth: 240),
        ),
        WidgetbookUseCase(
          name: 'long alt text',
          builder: (_) => frame(
            _tile(
              ToolImageState.idle,
              alt:
                  'A very long description of the picture that goes on and on '
                  'about the blue backpack on a wooden table by a window',
              host: 'a-very-long-sub-domain.images.cdn.example',
            ),
            maxWidth: 200,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ToolImageGallery',
      useCases: [
        WidgetbookUseCase(
          name: 'one image, large',
          builder: (_) => _gallery([
            _tile(ToolImageState.loaded, aspectRatio: 16 / 9),
          ], single: true),
        ),
        WidgetbookUseCase(
          name: 'generating',
          builder: (_) => _gallery([
            _tile(ToolImageState.generating, aspectRatio: 16 / 9),
          ], single: true),
        ),
        WidgetbookUseCase(
          name: 'generating, reduced motion',
          builder: (_) => _media(
            _gallery([
              _tile(ToolImageState.generating, aspectRatio: 16 / 9),
            ], single: true),
            still: true,
          ),
        ),
        WidgetbookUseCase(
          name: 'grid of nine (phone)',
          builder: (_) => _gallery(_nine()),
        ),
        WidgetbookUseCase(
          name: 'grid of nine (tablet)',
          builder: (_) => _gallery(_nine(), width: 640),
        ),
        WidgetbookUseCase(
          name: 'grid of nine (desktop)',
          builder: (_) => _gallery(_nine(), width: 900),
        ),
        WidgetbookUseCase(
          name: 'small ones hidden',
          builder: (_) => _gallery(_nine().take(3).toList(), hidden: 5),
        ),
        WidgetbookUseCase(
          name: 'grid of nine, German',
          builder: (_) => _german(_gallery(_nine(), hidden: 2)),
        ),
        WidgetbookUseCase(
          name: 'grid of nine, largest text',
          builder: (_) => _media(_gallery(_nine().take(4).toList()), scale: 3),
        ),
        WidgetbookUseCase(
          name: 'all small, hidden',
          builder: (_) => _gallery(const [], hidden: 4),
        ),
        WidgetbookUseCase(
          name: 'no images',
          builder: (_) => _gallery(const []),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ToolImagesBody',
      useCases: [
        WidgetbookUseCase(
          name: 'browser_get_images',
          builder: (_) => _card(
            imagesCall(
              imagesAnswer([
                pageImage(
                  'https://cdn.shop.example/front.png',
                  alt: 'Front view of the blue backpack',
                ),
                pageImage(
                  'https://cdn.shop.example/side.png',
                  alt: 'Side view',
                ),
                pageImage('http://old.example/logo.png', alt: 'Logo'),
                pageImage(
                  'https://cdn.shop.example/dot.gif',
                  width: 1,
                  height: 1,
                ),
              ]),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'image_generate: running',
          builder: (_) => _card(
            generateCall(
              null,
              args: const {'prompt': 'a backpack', 'aspect_ratio': 'landscape'},
              status: ToolCallStatus.running,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'image_generate: failed',
          builder: (_) => _card(
            generateCall({
              'success': false,
              'image': null,
              'error': 'The image service is busy.',
              'error_type': 'api_error',
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'browser_vision: a screenshot with the analysis',
          builder: (_) => _card(_vision()),
        ),
        ...onEachPlatform(
          'browser_get_images',
          (_) => _card(
            imagesCall(
              imagesAnswer([
                pageImage('https://cdn.shop.example/a.png', alt: 'Front view'),
                pageImage('https://cdn.shop.example/b.png', alt: 'Side view'),
              ]),
            ),
          ),
        ),
      ],
    ),
  ],
);
