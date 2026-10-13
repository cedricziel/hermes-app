class QueueScope {
  const QueueScope({
    required this.serverKey,
    required this.accountKey,
    required this.profile,
    required this.conversationId,
  });
  final String serverKey;
  final String accountKey;
  final String? profile;
  final String conversationId;
  Map<String, Object?> toJson() => {
    'server': serverKey,
    'account': accountKey,
    'profile': profile,
    'conversation': conversationId,
  };
}

enum QueueRecordState { queued, submissionStarted, accepted }

class QueueAttachmentInput {
  const QueueAttachmentInput({
    required this.path,
    required this.name,
    this.mimeType,
    this.isImage = false,
  });
  final String path;
  final String name;
  final String? mimeType;
  final bool isImage;
}

class QueueAttachment {
  const QueueAttachment({
    required this.blobId,
    required this.name,
    required this.size,
    this.mimeType,
    this.isImage = false,
  });
  final String blobId;
  final String name;
  final int size;
  final String? mimeType;
  final bool isImage;
  Map<String, Object?> toJson() => {
    'blob': blobId,
    'name': name,
    'size': size,
    'mime': mimeType,
    'image': isImage,
  };
  factory QueueAttachment.fromJson(Map<String, dynamic> value) =>
      QueueAttachment(
        blobId: value['blob'] as String,
        name: value['name'] as String,
        size: value['size'] as int,
        mimeType: value['mime'] as String?,
        isImage: value['image'] as bool,
      );
}

class QueueRecord {
  const QueueRecord({
    required this.id,
    required this.sequence,
    required this.text,
    this.displayText,
    this.state = QueueRecordState.queued,
    this.attachments = const [],
    this.submissionClaimHash,
  });
  final String id;
  final int sequence;
  final String text;
  final String? displayText;
  final QueueRecordState state;
  final String? submissionClaimHash;
  final List<QueueAttachment> attachments;
  Map<String, Object?> toJson() => {
    'id': id,
    'sequence': sequence,
    'text': text,
    'display': displayText,
    'state': state.name,
    'claim': submissionClaimHash,
    'attachments': [for (final file in attachments) file.toJson()],
  };
  factory QueueRecord.fromJson(Map<String, dynamic> value) => QueueRecord(
    id: value['id'] as String,
    sequence: value['sequence'] as int,
    text: value['text'] as String,
    displayText: value['display'] as String?,
    state: QueueRecordState.values.byName(value['state'] as String),
    submissionClaimHash: value['claim'] as String?,
    attachments: [
      for (final file in value['attachments'] as List)
        QueueAttachment.fromJson(Map<String, dynamic>.from(file as Map)),
    ],
  );
  QueueRecord withState(QueueRecordState next, {String? claimHash}) =>
      QueueRecord(
        id: id,
        sequence: sequence,
        text: text,
        displayText: displayText,
        state: next,
        submissionClaimHash: next == QueueRecordState.queued
            ? null
            : claimHash ?? submissionClaimHash,
        attachments: attachments,
      );
}

class QueueLoad {
  const QueueLoad(this.records, {this.corruptRecords = 0});
  final List<QueueRecord> records;
  final int corruptRecords;
}
