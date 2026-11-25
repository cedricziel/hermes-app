/// The colouring limit of `BoundedMarkdown` (see
/// `bounded_markdown_colour_limit_test.dart`) for fences inside other blocks:
/// lists, quotes, alerts, `<pre><code>`, `<details>` and table cells.
library;

import '../support/markdown_colour_harness.dart';

final _documents = <String, String Function()>{
  'bullet, numbered and nested lists': listFences,
  'quotes and nested quotes': quoteFences,
  'every alert kind': alertFences,
  'html pre code': htmlPre,
  'html details and table cells': detailsAndTables,
};

void main() => defineStreamCases(_documents);
