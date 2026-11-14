import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';

/// A 16 pt progress spinner; with reduced motion a still hourglass, since a
/// progress animation is what that setting turns off. Screen readers skip it:
/// the text beside it says what is going on.
class MotionSpinner extends StatelessWidget {
  const MotionSpinner({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 16,
      child: MediaQuery.disableAnimationsOf(context)
          ? AppIcon(
              AppIcons.waiting,
              size: 16,
              color: context.hermesColors.subtleText,
            )
          : const CircularProgressIndicator.adaptive(strokeWidth: 2),
    ),
  );
}
