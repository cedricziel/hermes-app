import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../auth/auth_controller.dart';
import '../telemetry/breadcrumbs.dart';
import 'share_controller.dart';
import 'share_inbox.dart';

/// The app's [ShareController]. It is not lazy: it reads the inbox at launch,
/// so content that started the app is held through setup and sign-in, and it
/// forgets a waiting quote when the user signs out whichever screen is shown.
SingleChildWidget shareProvider({ShareInbox? inbox}) =>
    ChangeNotifierProvider<ShareController>(
      lazy: false,
      create: (context) => ShareController(
        inbox ??
            createPlatformShareInbox(breadcrumbs: context.read<Breadcrumbs>()),
        signedOut: context.read<AuthController>().signedOut,
      )..start(),
    );
