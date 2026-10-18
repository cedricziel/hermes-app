import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/billing_verification_controller.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_controller.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_state.dart';
import 'package:hermes_app/src/chat/widgets/chat_thread_view.dart';

import '../../support/fake_attachment_source.dart';

void main() {
  testWidgets(
    'a chat with nothing to report starts its transcript below the header '
    'and keeps plans out of the transcript strip',
    (tester) async {
      Future<Map<String, Object?>> unsupported(Object? _, Object? _) async =>
          throw const GatewayRpcException(-32601, 'Unsupported');
      final todoScope = TodoScope(
        connection: Object(),
        runtimeId: 'runtime',
        profile: null,
      );
      final plan = TodoPlanState()..adopt(todoScope);
      final usage = SessionUsageController()
        ..bind(
          UsageScope(connection: Object(), sessionId: 'runtime', profile: null),
          unsupported,
        );
      final billing = BillingVerificationController()
        ..bind(
          BillingVerificationScope(
            connection: Object(),
            attachment: Object(),
            sessionId: 'runtime',
            profile: 'private-profile',
          ),
          request: (_) => unsupported(null, null),
        );
      final chat = InMemoryChatController();
      final composer = TextEditingController();
      final focus = FocusNode();
      final latest = ValueNotifier<String?>(null);
      for (final dispose in [
        plan.dispose,
        usage.dispose,
        billing.dispose,
        chat.dispose,
        composer.dispose,
        focus.dispose,
        latest.dispose,
      ]) {
        addTearDown(dispose);
      }
      await usage.opened();
      await billing.start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatThreadView(
              thread: null,
              chatController: chat,
              composerController: composer,
              composerFocus: focus,
              attachments: const [],
              attachmentSource: FakeAttachmentSource(),
              onAddAttachments: (_) {},
              onRemoveAttachment: (_) {},
              onSend: (_) {},
              onPickStarter: (_) {},
              latestReplyId: latest,
              billingVerification: billing,
              todoPlan: plan,
              welcome: false,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('chat-activity-strip')), findsNothing);

      plan.updated(todoScope, {
        'revision': 1,
        'todos': [
          {'id': 'a', 'content': 'Draft the brief', 'status': 'in_progress'},
        ],
      });
      await tester.pump();
      expect(find.byKey(const Key('chat-activity-strip')), findsNothing);
    },
  );
}
