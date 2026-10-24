// Response subset verified from learning_graph.py and learning_mutations.py at pinned source.
const memoryFixtureRevision = 'd923a5eb487a17c0a68801bba9ef0f56c81040a8';

/// A `memory[]` card as `_memory_cards` builds it: the file's `source`, a
/// `title` (the entry's first line, cut at 80), the `body` cut at 1200
/// characters, and the `fingerprint` of the whole entry. A card has no id; it
/// pairs with the memory node at the same position, which carries the same
/// `source` and `label` (the title).
Map<String, Object?> memoryCard(String source, String text) => {
  'source': source,
  'title': text.split('\n').first,
  'body': text.length > 1200 ? text.substring(0, 1200) : text,
  'fingerprint': 'digest',
  'timestamp': 1700000000,
};

/// `GET /api/config` keeps the limits under `memory`, with defaults included.
Map<String, Object?> memoryConfig({int? memoryLimit, int? userLimit}) => {
  'memory': {'memory_char_limit': ?memoryLimit, 'user_char_limit': ?userLimit},
};

const memoryId = 'memory:memory:0:digest';
final fullMemory = '${'Long memory content. ' * 100}\nhttps://example.invalid';
final memoryGraph = {
  'nodes': [
    {
      'id': memoryId,
      'kind': 'memory',
      'label': 'Long memory',
      'memorySource': 'memory',
    },
    {
      'id': 'memory:profile:1:other',
      'kind': 'memory',
      'label': 'User preference',
      'memorySource': 'profile',
    },
    {'id': 'skill', 'kind': 'skill', 'label': 'Skill'},
  ],
  // The long entry's card is kept short here so loading the list needs no
  // detail request; the cut at 1200 characters has its own tests.
  'memory': [
    memoryCard('memory', 'Long memory'),
    memoryCard('profile', 'User preference'),
  ],
};
final memoryDetail = {
  'ok': true,
  'kind': 'memory',
  'id': memoryId,
  'label': 'Long memory',
  'content': fullMemory,
};

const memoryMutationSuccess = {
  'ok': true,
  'message': 'updated memory in MEMORY.md',
};
const memoryMutationRejection = {
  'detail': 'empty memory — use delete to remove it',
};
const memoryStaleError = {
  'detail': 'memory node id is stale — refresh the graph',
};
