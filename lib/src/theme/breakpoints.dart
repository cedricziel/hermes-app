/// From this width in logical pixels a screen puts a list and its details
/// side by side, and opens forms in a dialog or pane instead of a page or
/// sheet.
const double kWideLayoutBreakpoint = 900;

/// From this width the Kanban board shows its columns side by side and opens
/// a task in a dialog. Lower than [kWideLayoutBreakpoint]: columns fit sooner.
const double kKanbanColumnsBreakpoint = 720;

/// The widest a skill's detail page or the skills list grows on a wide window.
const double kDetailContentMaxWidth = 720;
