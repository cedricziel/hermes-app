part of 'hermes_gateway_transport.dart';

/// Slash commands, the runtime session they run in, and attachments.
extension _Commands on HermesGatewayTransport {
  Future<List<SlashCommand>> _slashCommands({
    String? threadId,
    String? profile,
  }) async {
    final client = await _client();
    final runtimeId = threadId == null
        ? null
        : await _commandRuntime(client, threadId, profile);
    final result = await _call(client, 'commands.catalog', {
      'session_id': ?runtimeId,
      'profile': ?profile,
    });
    final pairs = result['pairs'];
    if (pairs is! List) return const [];
    final metadata = result['commands'];
    return [
      for (final pair in pairs)
        if (pair is List &&
            pair.length >= 2 &&
            pair[0] is String &&
            pair[1] is String &&
            (pair[0] as String).startsWith('/') &&
            !{'terminal', 'hidden'}.contains(
              metadata is Map && metadata[pair[0]] is Map
                  ? (metadata[pair[0]] as Map)['desktop']
                  : null,
            ))
          SlashCommand(pair[0] as String, pair[1] as String),
    ];
  }

  Future<SlashCommandResult> _runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  }) async {
    final client = await _client();
    final session = threadId == null
        ? await _call(client, 'session.create', {
            'profile': ?profile,
            'source': gatewaySessionSource,
          })
        : null;
    final runtimeId = threadId == null
        ? session!['session_id'] as String
        : await _commandRuntime(client, threadId, profile);
    final storedId = threadId ?? session!['stored_session_id'] as String;
    var current = command.trim().replaceFirst(RegExp(r'^/'), '');
    for (var depth = 0; depth < 5; depth++) {
      Map<String, Object?> result;
      try {
        result = await _call(client, 'slash.exec', {
          'session_id': runtimeId,
          'command': current,
        });
      } on GatewayRpcException catch (error) {
        if (error.code != 4018) rethrow;
        final parts = current.split(RegExp(r'\s+'));
        result = await _call(client, 'command.dispatch', {
          'session_id': runtimeId,
          'name': parts.first,
          'arg': current.substring(parts.first.length).trimLeft(),
        });
      }
      final type = result['type'];
      if (type == 'alias') {
        final target = result['target'];
        if (target is! String || target.trim().isEmpty) break;
        final targetCommand = target.trim().replaceFirst(RegExp(r'^/'), '');
        final name = current.split(RegExp(r'\s+')).first;
        final args = current.substring(name.length).trimLeft();
        current = args.isEmpty ? targetCommand : '$targetCommand $args';
        continue;
      }
      final prompt = (type == 'send' || type == 'skill')
          ? result['message'] as String?
          : null;
      return SlashCommandResult(
        threadId: storedId,
        output:
            result['output'] as String? ?? result['notice'] as String? ?? '',
        prompt: prompt,
        display: result['display'] as String?,
        prefill: type == 'prefill' ? result['message'] as String? : null,
      );
    }
    throw StateError('Could not resolve slash command');
  }

  Future<String> _commandRuntime(
    GatewayRpcClient client,
    String storedId,
    String? profile,
  ) async {
    final owner = (profile, storedId);
    final active = _runtimeOf[owner] ?? _idle[owner]?.runtimeId;
    if (active != null) return active;
    final session = await _call(client, 'session.resume', {
      'session_id': storedId,
      'profile': ?profile,
      'source': gatewaySessionSource,
    });
    return session['session_id'] as String;
  }

  /// Makes [attachments] available to the agent: an image is queued on the
  /// session (its path goes to [queued]), any other file is staged and its
  /// `@file:` reference returned for the prompt text.
  Future<List<String>> _attach(
    GatewayRpcClient client,
    String sessionId,
    List<OutgoingAttachment> attachments,
    List<String> queued, {
    required bool Function() reclaimed,
  }) async {
    final references = <String>[];
    for (final attachment in attachments) {
      if (reclaimed()) return references;
      final name = attachment.name;
      final Uint8List bytes;
      try {
        bytes = await attachment.read();
      } on Object {
        throw AttachmentException(
          attachmentFailedMessage(name, kAttachmentUnreadable),
        );
      }
      if (reclaimed()) return references;
      if (bytes.length > kMaxAttachmentBytes) {
        throw AttachmentException(attachmentTooLargeMessage(name));
      }
      final encoded = base64Encode(bytes);
      try {
        if (attachment.kind == AttachmentKind.image) {
          try {
            final result = await client.request('image.attach_bytes', {
              'session_id': sessionId,
              'content_base64': encoded,
              'filename': name,
            });
            if (result['path'] case final String path) queued.add(path);
            continue;
          } on GatewayRpcException catch (error) {
            // Not a format the model can see, but the agent can still open it.
            if (error.code != _unsupportedImage) rethrow;
          }
        }
        if (reclaimed()) return references;
        final result = await client.request('file.attach', {
          'session_id': sessionId,
          'name': name,
          'data_url':
              'data:${attachment.mimeType ?? 'application/octet-stream'}'
              ';base64,$encoded',
        });
        final reference = result['ref_text'];
        if (reference is! String || reference.isEmpty) {
          throw AttachmentException(
            attachmentFailedMessage(name, 'the server sent no reference.'),
          );
        }
        references.add(reference);
      } on GatewayRpcException catch (error) {
        throw AttachmentException(
          error.code == kGatewayMethodNotFound
              ? kAttachmentsUnsupportedMessage
              : attachmentFailedMessage(name, error.message),
        );
      }
    }
    return references;
  }

  Future<void> _detach(
    GatewayRpcClient client,
    String sessionId,
    List<String> queued,
  ) async {
    for (final path in queued) {
      try {
        await client.request('image.detach', {
          'session_id': sessionId,
          'path': path,
        });
      } on Object {
        // Best effort: the send already failed for another reason.
      }
    }
  }
}
