// Response subset verified from learning_graph.py and learning_mutations.py at pinned source.
const memoryFixtureRevision = '167e9fdb84248cd0fff80762dc57b6a914b6e930';
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
  'memory': [
    {'body': 'truncated preview'},
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
