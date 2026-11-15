import 'package:flutter/material.dart';

import 'platform_chrome.dart';

/// From this width in logical pixels a screen puts a list and its details
/// side by side, and opens forms in a dialog or pane instead of a page or
/// sheet. Read it through [isWideLayout], which also lets a full-screen iPad
/// in portrait through.
const double kWideLayoutBreakpoint = 900;

/// The narrowest an iPad is in full screen (an iPad mini in portrait, 744),
/// which is already regular width. Split View halves and Slide Over are
/// narrower.
const double kIpadRegularWidth = 700;

/// The shortest side an iPad has in full screen. A Split View window is
/// narrower than this on both axes, and so is an iPhone.
const double kIpadMinShortestSide = 600;

/// Whether a screen is laid out for regular width: a list beside its
/// details, a sidebar instead of a drawer, a dialog instead of a sheet.
///
/// [kWideLayoutBreakpoint] applies everywhere. On iOS a full-screen iPad
/// also counts, in either orientation, as iPadOS gives it a regular width
/// class. [width] is the room the caller has (its constraints) and defaults
/// to the window's width.
bool isWideLayout(BuildContext context, {double? width}) {
  final size = MediaQuery.sizeOf(context);
  final available = width ?? size.width;
  if (available >= kWideLayoutBreakpoint) return true;
  return platformChromeOf(context) == PlatformChrome.ios &&
      available >= kIpadRegularWidth &&
      size.shortestSide >= kIpadMinShortestSide;
}

/// From this content width a Mac window puts a list beside its details. A
/// Mac window's sidebar takes room [kWideLayoutBreakpoint] does not expect.
const double kMacSplitBreakpoint = 560;

/// From this width the Kanban board shows its columns side by side and opens
/// a task in a dialog. Lower than [kWideLayoutBreakpoint]: columns fit sooner.
const double kKanbanColumnsBreakpoint = 720;

/// The widest a skill's detail page or the skills list grows on a wide window.
const double kDetailContentMaxWidth = 720;

/// The smallest size of the Mac app's main window, set natively in
/// `MainFlutterWindow.minimumContentSize` (`contentMinSize`). AppKit applies it
/// against the window's full-size style mask, so it is read as a 640x480
/// frame: the Flutter view is 640x480 with the toolbar included. Its exact
/// effect is unmeasured until the CI measurement of the window.
const Size kMacMainWindowMinSize = Size(640, 480);

/// The default size of the Mac main window, the xib's content rect
/// (`MainMenu.xib`) before the title bar merges in: AppKit makes a 1100x788
/// frame and, with full-size content, the Flutter view is 1100x788. Above
/// [kWideLayoutBreakpoint]. Not the same sense as [kMacMainWindowMinSize].
const Size kMacMainWindowDefaultSize = Size(1100, 760);
