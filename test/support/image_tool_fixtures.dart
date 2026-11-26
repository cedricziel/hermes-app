import 'package:hermes_app/src/chat/chat_models.dart';

// The result shapes of `browser_get_images`, `image_generate` and
// `browser_vision` as Hermes builds them at d923a5eb (`tools/browser_tool.py`,
// `tools/image_generation_tool.py`), read from its source and not recorded
// from a running server; the contract PR that records the real bodies
// replaces these.

/// One entry of a `browser_get_images` answer.
Map<String, Object?> pageImage(
  String src, {
  String alt = '',
  int width = 800,
  int height = 600,
}) => {'src': src, 'alt': alt, 'width': width, 'height': height};

Map<String, Object?> imagesAnswer(List<Map<String, Object?>> images) => {
  'success': true,
  'images': images,
  'count': images.length,
};

ToolCall imagesCall(
  Object? answer, {
  ToolCallStatus status = ToolCallStatus.completed,
}) => ToolCall(
  name: 'browser_get_images',
  summary: '',
  resultData: answer,
  status: status,
);

ToolCall generateCall(
  Object? answer, {
  Map<String, Object?>? args = const {'prompt': 'a blue backpack'},
  ToolCallStatus status = ToolCallStatus.completed,
}) => ToolCall(
  name: 'image_generate',
  summary: '',
  args: args,
  resultData: answer,
  status: status,
);

Map<String, Object?> generated(String image) => {
  'success': true,
  'image': image,
  'modality': 'image',
  'upscaled': false,
};

ToolCall visionCall(Object? answer) => ToolCall(
  name: 'browser_vision',
  summary: '',
  args: const {'question': 'What is on the page?'},
  resultData: answer,
);

Map<String, Object?> visionAnswer({
  String path = '/home/hermes/.hermes/screenshots/page.png',
  String analysis = 'A shop page with a blue backpack and a buy button.',
}) => {'success': true, 'analysis': analysis, 'screenshot_path': path};
