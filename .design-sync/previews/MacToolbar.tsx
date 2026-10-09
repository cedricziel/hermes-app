import {
  HermesProvider,
  MacToolbar,
  MacToolbarButton,
  MacToolbarSearchField,
  MacToolbarSeparator,
  Menu,
  MenuAnchor,
  SegmentedControl,
} from "@hermes-app/ui";

const bar = { width: 760, border: "1px solid var(--h-border)" } as const;
const column = { display: "flex", flexDirection: "column", gap: 16 } as const;

const chatActions = (search: "field" | "button" | "active") => (
  <>
    <MacToolbarButton icon="edit_square" label="New Chat" shortcut="⌘N" />
    <MacToolbarButton icon="ios_share" label="Copy Transcript" />
    <MacToolbarButton icon="info_outline" label="Connection Details" />
    {search === "button" ? (
      <MacToolbarButton icon="search" label="Search" shortcut="⌘F" />
    ) : (
      <MacToolbarSearchField
        query={search === "active" ? "backup" : ""}
        active={search === "active"}
        focused={search === "active"}
      />
    )}
  </>
);

/** The chat's toolbar: title over "profile · model", New Chat, Copy Transcript, Connection Details and the search field (a window 1000px or wider); a narrower one shows a search button; while searching the field is wide with a focus ring and a clear button. */
export const Chat = () => (
  <HermesProvider platform="apple" typeRamp="default" style={column}>
    <div style={bar}>
      <MacToolbar
        title="Why did the nightly backup fail?"
        subtitle="default · claude-opus-4"
        actions={chatActions("field")}
      />
    </div>
    <div style={bar}>
      <MacToolbar
        title="Why did the nightly backup fail?"
        subtitle="default · claude-opus-4"
        actions={chatActions("button")}
      />
    </div>
    <div style={bar}>
      <MacToolbar
        title="Why did the nightly backup fail?"
        subtitle="default · claude-opus-4"
        actions={chatActions("active")}
      />
    </div>
  </HermesProvider>
);

/** A compact window folds Copy Transcript and Connection Details into a "…" menu; with the sidebar hidden the bar clears the traffic lights and leads with the show-sidebar button. */
export const CompactSidebarHidden = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={{ ...bar, width: 560, height: 150, position: "relative" }}>
      <span
        className="h-traffic-lights"
        style={{ position: "absolute", top: 20, left: 20 }}
      >
        <span />
        <span />
        <span />
      </span>
      <MacToolbar
        title="Plan the release"
        subtitle="default · claude-opus-4"
        sidebarHidden
        onShowSidebar={() => {}}
        actions={
          <>
            <MacToolbarButton
              icon="edit_square"
              label="New Chat"
              shortcut="⌘N"
            />
            <MenuAnchor>
              <MacToolbarButton icon="more_horiz" label="More" />
              <Menu
                align="end"
                device="mac"
                items={[
                  { label: "Copy Transcript" },
                  { label: "Connection Details" },
                ]}
              />
            </MenuAnchor>
            <MacToolbarButton icon="search" label="Search" shortcut="⌘F" />
          </>
        }
      />
    </div>
  </HermesProvider>
);

/** Kanban: a hairline under the bar, the board · profile scope · task count, New Task, the profile filter (filled while a profile is picked), the board menu, a separator and the inspector toggle (on). */
export const Kanban = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={bar}>
      <MacToolbar
        title="Kanban"
        subtitle="Main board · coder · 12 tasks"
        border
        actions={
          <>
            <MacToolbarButton icon="add" label="New Task" shortcut="⌘N" />
            <MacToolbarButton
              icon="filter_list"
              label="Filter by profile"
              selected
            />
            <MacToolbarButton
              icon="dashboard_customize_outlined"
              label="Switch board"
            />
            <MacToolbarSeparator />
            <MacToolbarButton
              icon="view_sidebar_outlined"
              label="Hide Inspector"
              shortcut="⌥⌘I"
              selected
            />
          </>
        }
      />
    </div>
  </HermesProvider>
);

/** Schedules: the job count, the This profile / All profiles scope, a separator, Refresh and New Schedule. */
export const Schedules = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={bar}>
      <MacToolbar
        title="Schedules"
        subtitle="4 jobs"
        border
        actions={
          <>
            <div style={{ width: 220 }}>
              <SegmentedControl
                labels={["This profile", "All profiles"]}
                value={0}
              />
            </div>
            <MacToolbarSeparator />
            <MacToolbarButton icon="refresh" label="Refresh" />
            <MacToolbarButton icon="add" label="New Schedule" shortcut="⌘N" />
          </>
        }
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    typeRamp="default"
    style={{ ...column, padding: 16, borderRadius: 14 }}
  >
    <div style={bar}>
      <MacToolbar
        title="Why did the nightly backup fail?"
        subtitle="default · claude-opus-4"
        actions={chatActions("active")}
      />
    </div>
    <div style={bar}>
      <MacToolbar
        title="Kanban"
        subtitle="Main board · all profiles · 12 tasks"
        border
        actions={
          <>
            <MacToolbarButton icon="add" label="New Task" shortcut="⌘N" />
            <MacToolbarButton icon="filter_list" label="Filter by profile" />
            <MacToolbarSeparator />
            <MacToolbarButton
              icon="view_sidebar_outlined"
              label="Show Inspector"
            />
          </>
        }
      />
    </div>
  </HermesProvider>
);

/** A pushed settings page: the `leading` back button before the title, compact tabs, the search field with a hint, then "+". */
export const PushedPage = () => (
  <HermesProvider platform="apple" typeRamp="default" style={column}>
    <div style={bar}>
      <MacToolbar
        title="Plugins"
        subtitle="work · 4 installed · 2 on"
        leading={
          <MacToolbarButton icon="chevron_left" label="Back" shortcut="⌘[" />
        }
        actions={
          <>
            <SegmentedControl
              labels={["Installed", "Catalog", "Providers"]}
              value={0}
              size="compact"
              platform="apple"
            />
            <MacToolbarSearchField hint="Search catalog" />
            <MacToolbarSeparator />
            <MacToolbarButton icon="add" label="Install from Git URL" />
          </>
        }
      />
    </div>
  </HermesProvider>
);
