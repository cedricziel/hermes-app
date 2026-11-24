// The trees `inline_dialog_extraction_test.dart` compares, recorded from the
// screens before the three pieces were extracted into their own widgets.

const expectedTrees = <String, String>{
  'inspect-alive': r'''== types ==
AppAlertDialog
  AlertDialog
    Dialog
      Semantics
        AnimatedPadding
          Padding
            MediaQuery
              Align
                ConstrainedBox
                  Material
                    _MaterialInterior
                      PhysicalShape
                        _ShapeBorderPaint
                          CustomPaint
                            NotificationListener<LayoutChangedNotification>
                              _InkFeatures
                                AnimatedDefaultTextStyle
                                  DefaultTextStyle
                                    Semantics
                                      IntrinsicWidth
                                        Column
                                          Padding
                                            DefaultTextStyle
                                              Semantics
                                                Text
                                                  RichText
                                          Flexible
                                            Padding
                                              DefaultTextStyle
                                                Semantics
                                                  Text
                                                    RichText
                                          Padding
                                            OverflowBar
                                              AppDialogAction
                                                TextButton
                                                  Semantics
                                                    _InputPadding
                                                      ConstrainedBox
                                                        Material
                                                          _MaterialInterior
                                                            PhysicalShape
                                                              _ShapeBorderPaint
                                                                CustomPaint
                                                                  NotificationListener<LayoutChangedNotification>
                                                                    _InkFeatures
                                                                      AnimatedDefaultTextStyle
                                                                        DefaultTextStyle
                                                                          AnimatedTheme
                                                                            Theme
                                                                              _InheritedTheme
                                                                                CupertinoTheme
                                                                                  InheritedCupertinoTheme
                                                                                    IconTheme
                                                                                      IconTheme
                                                                                        DefaultSelectionStyle
                                                                                          InkWell
                                                                                            _InkResponseStateWidget
                                                                                              _ParentInkResponseProvider
                                                                                                Actions
                                                                                                  _ActionsScope
                                                                                                    Focus
                                                                                                      _FocusInheritedScope
                                                                                                        Semantics
                                                                                                          MouseRegion
                                                                                                            Builder
                                                                                                              DefaultSelectionStyle
                                                                                                                Semantics
                                                                                                                  GestureDetector
                                                                                                                    RawGestureDetector
                                                                                                                      Listener
                                                                                                                        Padding
                                                                                                                          Align
                                                                                                                            Text
                                                                                                                              RichText
== texts ==
Run #7
---
Process 4242
Status: sleeping
Memory: 100 MB
Threads: 9
child of dispatcher
---
Close
== semantics ==
SemanticsNode#
 │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
 │
 └─SemanticsNode#
   │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │ textDirection: ltr
   │
   ├─SemanticsNode#
   │ │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │ │ sortKey: OrdinalSortKey#(order: 0.0)
   │ │
   │ └─SemanticsNode#
   │   │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │   │ flags: scopesRoute
   │   │
   │   └─SemanticsNode#
   │     │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │     │
   │     └─SemanticsNode#
   │       │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │       │ role: alertDialog
   │       │
   │       └─SemanticsNode#
   │         │ Rect.fromLTRB(90.6, 316.0, 409.4, 584.0)
   │         │ flags: scopesRoute, namesRoute
   │         │ label: "Alert"
   │         │ textDirection: ltr
   │         │
   │         ├─SemanticsNode#
   │         │   Rect.fromLTRB(24.0, 24.0, 294.8, 56.0)
   │         │   label: "Run #"
   │         │   textDirection: ltr
   │         │
   │         ├─SemanticsNode#
   │         │ │ Rect.fromLTRB(24.0, 72.0, 294.8, 172.0)
   │         │ │
   │         │ └─SemanticsNode#
   │         │     Rect.fromLTRB(0.0, 0.0, 270.8, 100.0)
   │         │     label:
   │         │       "Process 4242
   │         │       Status: sleeping
   │         │       Memory: 100 MB
   │         │       Threads: 9
   │         │       child of dispatcher"
   │         │     textDirection: ltr
   │         │
   │         └─SemanticsNode#
   │             Rect.fromLTRB(200.3, 196.0, 294.8, 244.0)
   │             actions: focus, tap
   │             flags: isButton, hasEnabledState, isEnabled, isFocusable
   │             label: "Close"
   │             textDirection: ltr
   │
   └─SemanticsNode#
       Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
       actions: dismiss, tap
       label: "Dismiss"
       textDirection: ltr
       sortKey: OrdinalSortKey#(order: 1.0)
''',
  'inspect-gone': r'''== types ==
AppAlertDialog
  AlertDialog
    Dialog
      Semantics
        AnimatedPadding
          Padding
            MediaQuery
              Align
                ConstrainedBox
                  Material
                    _MaterialInterior
                      PhysicalShape
                        _ShapeBorderPaint
                          CustomPaint
                            NotificationListener<LayoutChangedNotification>
                              _InkFeatures
                                AnimatedDefaultTextStyle
                                  DefaultTextStyle
                                    Semantics
                                      IntrinsicWidth
                                        Column
                                          Padding
                                            DefaultTextStyle
                                              Semantics
                                                Text
                                                  RichText
                                          Flexible
                                            Padding
                                              DefaultTextStyle
                                                Semantics
                                                  Text
                                                    RichText
                                          Padding
                                            OverflowBar
                                              AppDialogAction
                                                TextButton
                                                  Semantics
                                                    _InputPadding
                                                      ConstrainedBox
                                                        Material
                                                          _MaterialInterior
                                                            PhysicalShape
                                                              _ShapeBorderPaint
                                                                CustomPaint
                                                                  NotificationListener<LayoutChangedNotification>
                                                                    _InkFeatures
                                                                      AnimatedDefaultTextStyle
                                                                        DefaultTextStyle
                                                                          AnimatedTheme
                                                                            Theme
                                                                              _InheritedTheme
                                                                                CupertinoTheme
                                                                                  InheritedCupertinoTheme
                                                                                    IconTheme
                                                                                      IconTheme
                                                                                        DefaultSelectionStyle
                                                                                          InkWell
                                                                                            _InkResponseStateWidget
                                                                                              _ParentInkResponseProvider
                                                                                                Actions
                                                                                                  _ActionsScope
                                                                                                    Focus
                                                                                                      _FocusInheritedScope
                                                                                                        Semantics
                                                                                                          MouseRegion
                                                                                                            Builder
                                                                                                              DefaultSelectionStyle
                                                                                                                Semantics
                                                                                                                  GestureDetector
                                                                                                                    RawGestureDetector
                                                                                                                      Listener
                                                                                                                        Padding
                                                                                                                          Align
                                                                                                                            Text
                                                                                                                              RichText
== texts ==
Run #7
---
The process is not running: process not found.
---
Close
== semantics ==
SemanticsNode#
 │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
 │
 └─SemanticsNode#
   │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │ textDirection: ltr
   │
   ├─SemanticsNode#
   │ │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │ │ sortKey: OrdinalSortKey#(order: 0.0)
   │ │
   │ └─SemanticsNode#
   │   │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │   │ flags: scopesRoute
   │   │
   │   └─SemanticsNode#
   │     │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │     │
   │     └─SemanticsNode#
   │       │ Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
   │       │ role: alertDialog
   │       │
   │       └─SemanticsNode#
   │         │ Rect.fromLTRB(40.0, 336.0, 460.0, 564.0)
   │         │ flags: scopesRoute, namesRoute
   │         │ label: "Alert"
   │         │ textDirection: ltr
   │         │
   │         ├─SemanticsNode#
   │         │   Rect.fromLTRB(24.0, 24.0, 396.0, 56.0)
   │         │   label: "Run #"
   │         │   textDirection: ltr
   │         │
   │         ├─SemanticsNode#
   │         │ │ Rect.fromLTRB(24.0, 72.0, 396.0, 132.0)
   │         │ │
   │         │ └─SemanticsNode#
   │         │     Rect.fromLTRB(0.0, 0.0, 372.0, 60.0)
   │         │     label: "The process is not running: process not found."
   │         │     textDirection: ltr
   │         │
   │         └─SemanticsNode#
   │             Rect.fromLTRB(301.5, 156.0, 396.0, 204.0)
   │             actions: focus, tap
   │             flags: isButton, hasEnabledState, isEnabled, isFocusable
   │             label: "Close"
   │             textDirection: ltr
   │
   └─SemanticsNode#
       Rect.fromLTRB(0.0, 0.0, 500.0, 900.0)
       actions: dismiss, tap
       label: "Dismiss"
       textDirection: ltr
       sortKey: OrdinalSortKey#(order: 1.0)
''',
  'install-confirm': r'''== types ==
AppAlertDialog
  AlertDialog
    Dialog
      Semantics
        AnimatedPadding
          Padding
            MediaQuery
              Align
                ConstrainedBox
                  Material
                    _MaterialInterior
                      PhysicalShape
                        _ShapeBorderPaint
                          CustomPaint
                            NotificationListener<LayoutChangedNotification>
                              _InkFeatures
                                AnimatedDefaultTextStyle
                                  DefaultTextStyle
                                    Semantics
                                      IntrinsicWidth
                                        Column
                                          Padding
                                            DefaultTextStyle
                                              Semantics
                                                Text
                                                  RichText
                                          Flexible
                                            Padding
                                              DefaultTextStyle
                                                Semantics
                                                  Builder
                                                    DefaultTextStyle
                                                      SingleChildScrollView
                                                        PrimaryScrollController
                                                          Scrollable
                                                            StretchingOverscrollIndicator
                                                              NotificationListener<ScrollNotification>
                                                                AnimatedBuilder
                                                                  ClipRect
                                                                    StretchEffect
                                                                      Transform
                                                                        NotificationListener<ScrollMetricsNotification>
                                                                          _ScrollSemantics
                                                                            _ScrollableScope
                                                                              Listener
                                                                                RawGestureDetector
                                                                                  _GestureSemantics
                                                                                    Listener
                                                                                      Semantics
                                                                                        IgnorePointer
                                                                                          _SingleChildViewport
                                                                                            Column
                                                                                              Text
                                                                                                RichText
                                                                                              SizedBox
                                                                                              SkillScanFinding
                                                                                                Padding
                                                                                                  Column
                                                                                                    Text
                                                                                                      RichText
                                                                                                    Text
                                                                                                      RichText
                                                                                              SkillScanFinding
                                                                                                Padding
                                                                                                  Column
                                                                                                    Text
                                                                                                      RichText
                                                                                                    Text
                                                                                                      RichText
                                          Padding
                                            OverflowBar
                                              AppDialogAction
                                                TextButton
                                                  Semantics
                                                    _InputPadding
                                                      ConstrainedBox
                                                        Material
                                                          _MaterialInterior
                                                            PhysicalShape
                                                              _ShapeBorderPaint
                                                                CustomPaint
                                                                  NotificationListener<LayoutChangedNotification>
                                                                    _InkFeatures
                                                                      AnimatedDefaultTextStyle
                                                                        DefaultTextStyle
                                                                          AnimatedTheme
                                                                            Theme
                                                                              _InheritedTheme
                                                                                CupertinoTheme
                                                                                  InheritedCupertinoTheme
                                                                                    IconTheme
                                                                                      IconTheme
                                                                                        DefaultSelectionStyle
                                                                                          InkWell
                                                                                            _InkResponseStateWidget
                                                                                              _ParentInkResponseProvider
                                                                                                Actions
                                                                                                  _ActionsScope
                                                                                                    Focus
                                                                                                      _FocusInheritedScope
                                                                                                        Semantics
                                                                                                          MouseRegion
                                                                                                            Builder
                                                                                                              DefaultSelectionStyle
                                                                                                                Semantics
                                                                                                                  GestureDetector
                                                                                                                    RawGestureDetector
                                                                                                                      Listener
                                                                                                                        Padding
                                                                                                                          Align
                                                                                                                            Text
                                                                                                                              RichText
                                              AppDialogAction
                                                FilledButton
                                                  Semantics
                                                    _InputPadding
                                                      ConstrainedBox
                                                        Material
                                                          _MaterialInterior
                                                            PhysicalShape
                                                              _ShapeBorderPaint
                                                                CustomPaint
                                                                  NotificationListener<LayoutChangedNotification>
                                                                    _InkFeatures
                                                                      AnimatedDefaultTextStyle
                                                                        DefaultTextStyle
                                                                          AnimatedTheme
                                                                            Theme
                                                                              _InheritedTheme
                                                                                CupertinoTheme
                                                                                  InheritedCupertinoTheme
                                                                                    IconTheme
                                                                                      IconTheme
                                                                                        DefaultSelectionStyle
                                                                                          InkWell
                                                                                            _InkResponseStateWidget
                                                                                              _ParentInkResponseProvider
                                                                                                Actions
                                                                                                  _ActionsScope
                                                                                                    Focus
                                                                                                      _FocusInheritedScope
                                                                                                        Semantics
                                                                                                          MouseRegion
                                                                                                            Builder
                                                                                                              DefaultSelectionStyle
                                                                                                                Semantics
                                                                                                                  GestureDetector
                                                                                                                    RawGestureDetector
                                                                                                                      Listener
                                                                                                                        Padding
                                                                                                                          Align
                                                                                                                            Text
                                                                                                                              RichText
== texts ==
Install web-scraper?
---
Findings need a look.
---
HIGH  Downloads and runs a remote script
---
scripts/fetch.sh:12
---
LOW  Reads the environment
---
scripts/env.sh:3
---
Cancel
---
Install anyway
== semantics ==
SemanticsNode#
 │ Rect.fromLTRB(0.0, 0.0, 800.0, 1400.0)
 │
 └─SemanticsNode#
   │ Rect.fromLTRB(0.0, 0.0, 800.0, 1400.0)
   │ textDirection: ltr
   │
   ├─SemanticsNode#
   │ │ Rect.fromLTRB(0.0, 0.0, 800.0, 1400.0)
   │ │ sortKey: OrdinalSortKey#(order: 0.0)
   │ │
   │ └─SemanticsNode#
   │   │ Rect.fromLTRB(0.0, 0.0, 800.0, 1400.0)
   │   │ flags: scopesRoute
   │   │
   │   └─SemanticsNode#
   │     │ Rect.fromLTRB(0.0, 0.0, 800.0, 1400.0)
   │     │
   │     └─SemanticsNode#
   │       │ Rect.fromLTRB(0.0, 0.0, 800.0, 1400.0)
   │       │ role: alertDialog
   │       │
   │       └─SemanticsNode#
   │         │ Rect.fromLTRB(120.0, 546.0, 680.0, 854.0)
   │         │ flags: scopesRoute, namesRoute
   │         │ label: "Alert"
   │         │ textDirection: ltr
   │         │
   │         ├─SemanticsNode#
   │         │   Rect.fromLTRB(24.0, 24.0, 536.0, 56.0)
   │         │   label: "Install web-scraper?"
   │         │   textDirection: ltr
   │         │
   │         ├─SemanticsNode#
   │         │ │ Rect.fromLTRB(24.0, 72.0, 536.0, 212.0)
   │         │ │
   │         │ └─SemanticsNode#
   │         │   │ Rect.fromLTRB(0.0, 0.0, 512.0, 140.0)
   │         │   │ flags: hasImplicitScrolling
   │         │   │ scrollExtentMin: 0.0
   │         │   │ scrollPosition: 0.0
   │         │   │ scrollExtentMax: 0.0
   │         │   │
   │         │   ├─SemanticsNode#
   │         │   │   Rect.fromLTRB(0.0, 0.0, 512.0, 20.0)
   │         │   │   label: "Findings need a look."
   │         │   │   textDirection: ltr
   │         │   │
   │         │   ├─SemanticsNode#
   │         │   │   Rect.fromLTRB(0.0, 36.0, 512.0, 76.0)
   │         │   │   label: "HIGH  Downloads and runs a remote script"
   │         │   │   textDirection: ltr
   │         │   │
   │         │   ├─SemanticsNode#
   │         │   │   Rect.fromLTRB(0.0, 76.0, 512.0, 92.0)
   │         │   │   label: "scripts/fetch.sh:12"
   │         │   │   textDirection: ltr
   │         │   │
   │         │   ├─SemanticsNode#
   │         │   │   Rect.fromLTRB(0.0, 100.0, 512.0, 120.0)
   │         │   │   label: "LOW  Reads the environment"
   │         │   │   textDirection: ltr
   │         │   │
   │         │   └─SemanticsNode#
   │         │       Rect.fromLTRB(0.0, 120.0, 512.0, 136.0)
   │         │       label: "scripts/env.sh:3"
   │         │       textDirection: ltr
   │         │
   │         ├─SemanticsNode#
   │         │   Rect.fromLTRB(174.0, 236.0, 282.6, 284.0)
   │         │   actions: focus, tap
   │         │   flags: isButton, hasEnabledState, isEnabled, isFocusable
   │         │   label: "Cancel"
   │         │   textDirection: ltr
   │         │
   │         └─SemanticsNode#
   │             Rect.fromLTRB(290.6, 236.0, 536.0, 284.0)
   │             actions: focus, tap
   │             flags: isButton, hasEnabledState, isEnabled, isFocusable
   │             label: "Install anyway"
   │             textDirection: ltr
   │
   └─SemanticsNode#
       Rect.fromLTRB(0.0, 0.0, 800.0, 1400.0)
       actions: dismiss, tap
       label: "Dismiss"
       textDirection: ltr
       sortKey: OrdinalSortKey#(order: 1.0)
''',
  'menu-idle': r'''== closed ==
== types ==
NamedPopupMenuButton<_More>
  Tooltip
    RawTooltip
      OverlayPortal
        _OverlayPortal
          Semantics
            _ExclusiveMouseRegion
              Listener
                Semantics
                  MouseRegion
                    AdaptivePopupMenuButton<_More>
                      Theme
                        _InheritedTheme
                          CupertinoTheme
                            InheritedCupertinoTheme
                              IconTheme
                                IconTheme
                                  DefaultSelectionStyle
                                    PopupMenuButton<_More>
                                      Semantics
                                        IconButton
                                          _SelectableIconButton
                                            _IconButtonM3
                                              Semantics
                                                _InputPadding
                                                  ConstrainedBox
                                                    Material
                                                      _MaterialInterior
                                                        PhysicalShape
                                                          _ShapeBorderPaint
                                                            CustomPaint
                                                              NotificationListener<LayoutChangedNotification>
                                                                _InkFeatures
                                                                  AnimatedDefaultTextStyle
                                                                    DefaultTextStyle
                                                                      Tooltip
                                                                        AnimatedTheme
                                                                          Theme
                                                                            _InheritedTheme
                                                                              CupertinoTheme
                                                                                InheritedCupertinoTheme
                                                                                  IconTheme
                                                                                    IconTheme
                                                                                      DefaultSelectionStyle
                                                                                        InkWell
                                                                                          _InkResponseStateWidget
                                                                                            _ParentInkResponseProvider
                                                                                              Actions
                                                                                                _ActionsScope
                                                                                                  Focus
                                                                                                    _FocusInheritedScope
                                                                                                      Semantics
                                                                                                        MouseRegion
                                                                                                          Builder
                                                                                                            DefaultSelectionStyle
                                                                                                              Semantics
                                                                                                                GestureDetector
                                                                                                                  RawGestureDetector
                                                                                                                    Listener
                                                                                                                      Padding
                                                                                                                        Align
                                                                                                                          Semantics
                                                                                                                            Semantics
                                                                                                                              AppIcon
                                                                                                                                Icon
                                                                                                                                  Semantics
                                                                                                                                    ExcludeSemantics
                                                                                                                                      SizedBox
                                                                                                                                        Center
                                                                                                                                          RichText
== texts ==

== semantics ==
SemanticsNode#
 │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
 │
 └─SemanticsNode#
   │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
   │ textDirection: ltr
   │
   └─SemanticsNode#
     │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
     │ sortKey: OrdinalSortKey#(order: 0.0)
     │
     └─SemanticsNode#
       │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
       │ flags: scopesRoute
       │
       └─SemanticsNode#
         │ Rect.fromLTRB(0.0, 0.0, 680.0, 52.0)
         │ actions: scrollDown, scrollLeft, scrollRight, scrollUp
         │ traversalParentIdentifier: _OverlayPortalState#
         │ label:
         │   "Plan the release
         │   default · claude-sonnet-4"
         │ textDirection: ltr
         │
         ├─SemanticsNode#
         │   Rect.fromLTRB(544.0, 12.0, 572.0, 40.0)
         │   actions: focus, tap
         │   flags: isButton, hasEnabledState, isEnabled, isFocusable
         │   label: "New Chat"
         │   textDirection: ltr
         │
         ├─SemanticsNode#
         │   Rect.fromLTRB(576.0, 12.0, 604.0, 40.0)
         │   actions: focus, tap
         │   flags: isButton, hasEnabledState, isEnabled, isFocusable,
         │     hasExpandedState
         │   label: "More"
         │   textDirection: ltr
         │
         ├─SemanticsNode#
         │   Rect.fromLTRB(608.0, 12.0, 636.0, 40.0)
         │   flags: isButton, hasEnabledState, hasSelectedState
         │   label: "Show Inspector"
         │   textDirection: ltr
         │
         └─SemanticsNode#
             Rect.fromLTRB(640.0, 12.0, 668.0, 40.0)
             actions: focus, tap
             flags: isButton, hasEnabledState, isEnabled, isFocusable
             label: "Search"
             textDirection: ltr
== open ==
== types ==
_PopupMenu<_More?>
  AnimatedBuilder
    FadeTransition
      Material
        _MaterialInterior
          PhysicalShape
            _ShapeBorderPaint
              CustomPaint
                NotificationListener<LayoutChangedNotification>
                  _InkFeatures
                    AnimatedDefaultTextStyle
                      DefaultTextStyle
                        Align
                          ConstrainedBox
                            IntrinsicWidth
                              Semantics
                                SingleChildScrollView
                                  Scrollable
                                    Scrollbar
                                      _MaterialScrollbar
                                        NotificationListener<ScrollMetricsNotification>
                                          NotificationListener<ScrollNotification>
                                            RepaintBoundary
                                              Listener
                                                RawGestureDetector
                                                  _GestureSemantics
                                                    Listener
                                                      MouseRegion
                                                        CustomPaint
                                                          RepaintBoundary
                                                            NotificationListener<ScrollMetricsNotification>
                                                              _ScrollSemantics
                                                                _ScrollableScope
                                                                  Listener
                                                                    RawGestureDetector
                                                                      _GestureSemantics
                                                                        Listener
                                                                          Semantics
                                                                            IgnorePointer
                                                                              _SingleChildViewport
                                                                                Padding
                                                                                  ListBody
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                AnimatedDefaultTextStyle
                                                                                                                                  DefaultTextStyle
                                                                                                                                    ConstrainedBox
                                                                                                                                      Padding
                                                                                                                                        Align
                                                                                                                                          MacMenuRow
                                                                                                                                            MouseRegion
                                                                                                                                              KeyboardFocusBuilder
                                                                                                                                                CustomPaint
                                                                                                                                                  Container
                                                                                                                                                    ConstrainedBox
                                                                                                                                                      DecoratedBox
                                                                                                                                                        Padding
                                                                                                                                                          Builder
                                                                                                                                                            DefaultTextStyle
                                                                                                                                                              Row
                                                                                                                                                                Expanded
                                                                                                                                                                  Text
                                                                                                                                                                    RichText
                                                                                                                                                                SizedBox
                                                                                                                                                                Text
                                                                                                                                                                  RichText
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                AnimatedDefaultTextStyle
                                                                                                                                  DefaultTextStyle
                                                                                                                                    ConstrainedBox
                                                                                                                                      Padding
                                                                                                                                        Align
                                                                                                                                          MacMenuRow
                                                                                                                                            MouseRegion
                                                                                                                                              KeyboardFocusBuilder
                                                                                                                                                CustomPaint
                                                                                                                                                  Container
                                                                                                                                                    ConstrainedBox
                                                                                                                                                      DecoratedBox
                                                                                                                                                        Padding
                                                                                                                                                          Builder
                                                                                                                                                            DefaultTextStyle
                                                                                                                                                              Row
                                                                                                                                                                Expanded
                                                                                                                                                                  Text
                                                                                                                                                                    RichText
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                AnimatedDefaultTextStyle
                                                                                                                                  DefaultTextStyle
                                                                                                                                    ConstrainedBox
                                                                                                                                      Padding
                                                                                                                                        Align
                                                                                                                                          MacMenuRow
                                                                                                                                            MouseRegion
                                                                                                                                              KeyboardFocusBuilder
                                                                                                                                                CustomPaint
                                                                                                                                                  Container
                                                                                                                                                    ConstrainedBox
                                                                                                                                                      DecoratedBox
                                                                                                                                                        Padding
                                                                                                                                                          Builder
                                                                                                                                                            DefaultTextStyle
                                                                                                                                                              Row
                                                                                                                                                                Expanded
                                                                                                                                                                  Text
                                                                                                                                                                    RichText
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                AnimatedDefaultTextStyle
                                                                                                                                  DefaultTextStyle
                                                                                                                                    ConstrainedBox
                                                                                                                                      Padding
                                                                                                                                        Align
                                                                                                                                          MacMenuRow
                                                                                                                                            MouseRegion
                                                                                                                                              KeyboardFocusBuilder
                                                                                                                                                CustomPaint
                                                                                                                                                  Container
                                                                                                                                                    ConstrainedBox
                                                                                                                                                      DecoratedBox
                                                                                                                                                        Padding
                                                                                                                                                          Builder
                                                                                                                                                            DefaultTextStyle
                                                                                                                                                              Row
                                                                                                                                                                Expanded
                                                                                                                                                                  Text
                                                                                                                                                                    RichText
== texts ==
Show Files
---
⇧⌘F
---
Copy Transcript
---
Export Chat as JSON…
---
Connection Details
== semantics ==
SemanticsNode#
 │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
 │
 └─SemanticsNode#
   │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
   │ textDirection: ltr
   │
   ├─SemanticsNode#
   │ │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
   │ │ sortKey: OrdinalSortKey#(order: 0.0)
   │ │
   │ └─SemanticsNode#
   │   │ Rect.fromLTRB(324.0, 12.0, 604.0, 108.0)
   │   │ flags: scopesRoute, namesRoute
   │   │ label: "Popup menu"
   │   │ textDirection: ltr
   │   │ role: menu
   │   │
   │   └─SemanticsNode#
   │     │ Rect.fromLTRB(0.0, 0.0, 280.0, 96.0)
   │     │ flags: hasImplicitScrolling
   │     │ scrollExtentMin: 0.0
   │     │ scrollPosition: 0.0
   │     │ scrollExtentMax: 0.0
   │     │
   │     ├─SemanticsNode#
   │     │   merge boundary ⛔️
   │     │   Rect.fromLTRB(0.0, 4.0, 280.0, 26.0)
   │     │   actions: focus, tap
   │     │   flags: isButton, hasEnabledState, isEnabled, isFocusable
   │     │   label:
   │     │     "Show Files
   │     │     ⇧⌘F"
   │     │   textDirection: ltr
   │     │   role: menuItem
   │     │
   │     ├─SemanticsNode#
   │     │   merge boundary ⛔️
   │     │   Rect.fromLTRB(0.0, 26.0, 280.0, 48.0)
   │     │   actions: focus, tap
   │     │   flags: isButton, hasEnabledState, isEnabled, isFocusable
   │     │   label: "Copy Transcript"
   │     │   textDirection: ltr
   │     │   role: menuItem
   │     │
   │     ├─SemanticsNode#
   │     │   merge boundary ⛔️
   │     │   Rect.fromLTRB(0.0, 48.0, 280.0, 70.0)
   │     │   actions: focus, tap
   │     │   flags: isButton, hasEnabledState, isEnabled, isFocusable
   │     │   label: "Export Chat as JSON…"
   │     │   textDirection: ltr
   │     │   role: menuItem
   │     │
   │     └─SemanticsNode#
   │         merge boundary ⛔️
   │         Rect.fromLTRB(0.0, 70.0, 280.0, 92.0)
   │         actions: focus, tap
   │         flags: isButton, hasEnabledState, isEnabled, isFocusable
   │         label: "Connection Details"
   │         textDirection: ltr
   │         role: menuItem
   │
   └─SemanticsNode#
       Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
       actions: dismiss, tap
       label: "Dismiss menu"
       textDirection: ltr
       sortKey: OrdinalSortKey#(order: 1.0)
''',
  'menu-export running': r'''== closed ==
== types ==
NamedPopupMenuButton<_More>
  Tooltip
    RawTooltip
      OverlayPortal
        _OverlayPortal
          Semantics
            _ExclusiveMouseRegion
              Listener
                Semantics
                  MouseRegion
                    AdaptivePopupMenuButton<_More>
                      Theme
                        _InheritedTheme
                          CupertinoTheme
                            InheritedCupertinoTheme
                              IconTheme
                                IconTheme
                                  DefaultSelectionStyle
                                    PopupMenuButton<_More>
                                      Semantics
                                        IconButton
                                          _SelectableIconButton
                                            _IconButtonM3
                                              Semantics
                                                _InputPadding
                                                  ConstrainedBox
                                                    Material
                                                      _MaterialInterior
                                                        PhysicalShape
                                                          _ShapeBorderPaint
                                                            CustomPaint
                                                              NotificationListener<LayoutChangedNotification>
                                                                _InkFeatures
                                                                  AnimatedDefaultTextStyle
                                                                    DefaultTextStyle
                                                                      Tooltip
                                                                        AnimatedTheme
                                                                          Theme
                                                                            _InheritedTheme
                                                                              CupertinoTheme
                                                                                InheritedCupertinoTheme
                                                                                  IconTheme
                                                                                    IconTheme
                                                                                      DefaultSelectionStyle
                                                                                        InkWell
                                                                                          _InkResponseStateWidget
                                                                                            _ParentInkResponseProvider
                                                                                              Actions
                                                                                                _ActionsScope
                                                                                                  Focus
                                                                                                    _FocusInheritedScope
                                                                                                      Semantics
                                                                                                        MouseRegion
                                                                                                          Builder
                                                                                                            DefaultSelectionStyle
                                                                                                              Semantics
                                                                                                                GestureDetector
                                                                                                                  RawGestureDetector
                                                                                                                    Listener
                                                                                                                      Padding
                                                                                                                        Align
                                                                                                                          Semantics
                                                                                                                            Semantics
                                                                                                                              AppIcon
                                                                                                                                Icon
                                                                                                                                  Semantics
                                                                                                                                    ExcludeSemantics
                                                                                                                                      SizedBox
                                                                                                                                        Center
                                                                                                                                          RichText
== texts ==

== semantics ==
SemanticsNode#
 │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
 │
 └─SemanticsNode#
   │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
   │ textDirection: ltr
   │
   └─SemanticsNode#
     │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
     │ sortKey: OrdinalSortKey#(order: 0.0)
     │
     └─SemanticsNode#
       │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
       │ flags: scopesRoute
       │
       └─SemanticsNode#
         │ Rect.fromLTRB(0.0, 0.0, 680.0, 52.0)
         │ actions: scrollDown, scrollLeft, scrollRight, scrollUp
         │ traversalParentIdentifier: _OverlayPortalState#
         │ label:
         │   "Plan the release
         │   default · claude-sonnet-4"
         │ textDirection: ltr
         │
         ├─SemanticsNode#
         │   Rect.fromLTRB(544.0, 12.0, 572.0, 40.0)
         │   actions: focus, tap
         │   flags: isButton, hasEnabledState, isEnabled, isFocusable
         │   label: "New Chat"
         │   textDirection: ltr
         │
         ├─SemanticsNode#
         │   Rect.fromLTRB(576.0, 12.0, 604.0, 40.0)
         │   actions: focus, tap
         │   flags: isButton, hasEnabledState, isEnabled, isFocusable,
         │     hasExpandedState
         │   label: "More"
         │   textDirection: ltr
         │
         ├─SemanticsNode#
         │   Rect.fromLTRB(608.0, 12.0, 636.0, 40.0)
         │   flags: isButton, hasEnabledState, hasSelectedState
         │   label: "Show Inspector"
         │   textDirection: ltr
         │
         └─SemanticsNode#
             Rect.fromLTRB(640.0, 12.0, 668.0, 40.0)
             actions: focus, tap
             flags: isButton, hasEnabledState, isEnabled, isFocusable
             label: "Search"
             textDirection: ltr
== open ==
== types ==
_PopupMenu<_More?>
  AnimatedBuilder
    FadeTransition
      Material
        _MaterialInterior
          PhysicalShape
            _ShapeBorderPaint
              CustomPaint
                NotificationListener<LayoutChangedNotification>
                  _InkFeatures
                    AnimatedDefaultTextStyle
                      DefaultTextStyle
                        Align
                          ConstrainedBox
                            IntrinsicWidth
                              Semantics
                                SingleChildScrollView
                                  Scrollable
                                    Scrollbar
                                      _MaterialScrollbar
                                        NotificationListener<ScrollMetricsNotification>
                                          NotificationListener<ScrollNotification>
                                            RepaintBoundary
                                              Listener
                                                RawGestureDetector
                                                  _GestureSemantics
                                                    Listener
                                                      MouseRegion
                                                        CustomPaint
                                                          RepaintBoundary
                                                            NotificationListener<ScrollMetricsNotification>
                                                              _ScrollSemantics
                                                                _ScrollableScope
                                                                  Listener
                                                                    RawGestureDetector
                                                                      _GestureSemantics
                                                                        Listener
                                                                          Semantics
                                                                            IgnorePointer
                                                                              _SingleChildViewport
                                                                                Padding
                                                                                  ListBody
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                AnimatedDefaultTextStyle
                                                                                                                                  DefaultTextStyle
                                                                                                                                    ConstrainedBox
                                                                                                                                      Padding
                                                                                                                                        Align
                                                                                                                                          MacMenuRow
                                                                                                                                            MouseRegion
                                                                                                                                              KeyboardFocusBuilder
                                                                                                                                                CustomPaint
                                                                                                                                                  Container
                                                                                                                                                    ConstrainedBox
                                                                                                                                                      DecoratedBox
                                                                                                                                                        Padding
                                                                                                                                                          Builder
                                                                                                                                                            DefaultTextStyle
                                                                                                                                                              Row
                                                                                                                                                                Expanded
                                                                                                                                                                  Text
                                                                                                                                                                    RichText
                                                                                                                                                                SizedBox
                                                                                                                                                                Text
                                                                                                                                                                  RichText
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                AnimatedDefaultTextStyle
                                                                                                                                  DefaultTextStyle
                                                                                                                                    ConstrainedBox
                                                                                                                                      Padding
                                                                                                                                        Align
                                                                                                                                          MacMenuRow
                                                                                                                                            MouseRegion
                                                                                                                                              KeyboardFocusBuilder
                                                                                                                                                CustomPaint
                                                                                                                                                  Container
                                                                                                                                                    ConstrainedBox
                                                                                                                                                      DecoratedBox
                                                                                                                                                        Padding
                                                                                                                                                          Builder
                                                                                                                                                            DefaultTextStyle
                                                                                                                                                              Row
                                                                                                                                                                Expanded
                                                                                                                                                                  Text
                                                                                                                                                                    RichText
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                Builder
                                                                                                                                  IconTheme
                                                                                                                                    AnimatedDefaultTextStyle
                                                                                                                                      DefaultTextStyle
                                                                                                                                        ConstrainedBox
                                                                                                                                          Padding
                                                                                                                                            Align
                                                                                                                                              MacMenuRow
                                                                                                                                                MouseRegion
                                                                                                                                                  KeyboardFocusBuilder
                                                                                                                                                    CustomPaint
                                                                                                                                                      Container
                                                                                                                                                        ConstrainedBox
                                                                                                                                                          DecoratedBox
                                                                                                                                                            Padding
                                                                                                                                                              Builder
                                                                                                                                                                DefaultTextStyle
                                                                                                                                                                  Row
                                                                                                                                                                    Expanded
                                                                                                                                                                      Text
                                                                                                                                                                        RichText
                                                                                    _MenuItem
                                                                                      FadeTransition
                                                                                        PopupMenuItem<_More>
                                                                                          MergeSemantics
                                                                                            Semantics
                                                                                              InkWell
                                                                                                _InkResponseStateWidget
                                                                                                  _ParentInkResponseProvider
                                                                                                    Actions
                                                                                                      _ActionsScope
                                                                                                        Focus
                                                                                                          _FocusInheritedScope
                                                                                                            Semantics
                                                                                                              MouseRegion
                                                                                                                Builder
                                                                                                                  DefaultSelectionStyle
                                                                                                                    Semantics
                                                                                                                      GestureDetector
                                                                                                                        RawGestureDetector
                                                                                                                          Listener
                                                                                                                            Builder
                                                                                                                              ListTileTheme
                                                                                                                                AnimatedDefaultTextStyle
                                                                                                                                  DefaultTextStyle
                                                                                                                                    ConstrainedBox
                                                                                                                                      Padding
                                                                                                                                        Align
                                                                                                                                          MacMenuRow
                                                                                                                                            MouseRegion
                                                                                                                                              KeyboardFocusBuilder
                                                                                                                                                CustomPaint
                                                                                                                                                  Container
                                                                                                                                                    ConstrainedBox
                                                                                                                                                      DecoratedBox
                                                                                                                                                        Padding
                                                                                                                                                          Builder
                                                                                                                                                            DefaultTextStyle
                                                                                                                                                              Row
                                                                                                                                                                Expanded
                                                                                                                                                                  Text
                                                                                                                                                                    RichText
== texts ==
Show Files
---
⇧⌘F
---
Copy Transcript
---
Export Chat as JSON…
---
Connection Details
== semantics ==
SemanticsNode#
 │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
 │
 └─SemanticsNode#
   │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
   │ textDirection: ltr
   │
   ├─SemanticsNode#
   │ │ Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
   │ │ sortKey: OrdinalSortKey#(order: 0.0)
   │ │
   │ └─SemanticsNode#
   │   │ Rect.fromLTRB(324.0, 12.0, 604.0, 108.0)
   │   │ flags: scopesRoute, namesRoute
   │   │ label: "Popup menu"
   │   │ textDirection: ltr
   │   │ role: menu
   │   │
   │   └─SemanticsNode#
   │     │ Rect.fromLTRB(0.0, 0.0, 280.0, 96.0)
   │     │ flags: hasImplicitScrolling
   │     │ scrollExtentMin: 0.0
   │     │ scrollPosition: 0.0
   │     │ scrollExtentMax: 0.0
   │     │
   │     ├─SemanticsNode#
   │     │   merge boundary ⛔️
   │     │   Rect.fromLTRB(0.0, 4.0, 280.0, 26.0)
   │     │   actions: focus, tap
   │     │   flags: isButton, hasEnabledState, isEnabled, isFocusable
   │     │   label:
   │     │     "Show Files
   │     │     ⇧⌘F"
   │     │   textDirection: ltr
   │     │   role: menuItem
   │     │
   │     ├─SemanticsNode#
   │     │   merge boundary ⛔️
   │     │   Rect.fromLTRB(0.0, 26.0, 280.0, 48.0)
   │     │   actions: focus, tap
   │     │   flags: isButton, hasEnabledState, isEnabled, isFocusable
   │     │   label: "Copy Transcript"
   │     │   textDirection: ltr
   │     │   role: menuItem
   │     │
   │     ├─SemanticsNode#
   │     │   merge boundary ⛔️
   │     │   Rect.fromLTRB(0.0, 48.0, 280.0, 70.0)
   │     │   flags: isButton, hasEnabledState
   │     │   label: "Export Chat as JSON…"
   │     │   textDirection: ltr
   │     │   role: menuItem
   │     │
   │     └─SemanticsNode#
   │         merge boundary ⛔️
   │         Rect.fromLTRB(0.0, 70.0, 280.0, 92.0)
   │         actions: focus, tap
   │         flags: isButton, hasEnabledState, isEnabled, isFocusable
   │         label: "Connection Details"
   │         textDirection: ltr
   │         role: menuItem
   │
   └─SemanticsNode#
       Rect.fromLTRB(0.0, 0.0, 680.0, 700.0)
       actions: dismiss, tap
       label: "Dismiss menu"
       textDirection: ltr
       sortKey: OrdinalSortKey#(order: 1.0)
''',
};
