import {
  Badge,
  HermesProvider,
  IconButton,
  ListRow,
  Spinner,
  Switch,
} from "@hermes-app/ui";

const panel = {
  width: 380,
  padding: "12px 0",
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  background: "var(--h-bg)",
} as const;

const more = <IconButton icon="more_vert" label="Board actions" tone="muted" />;

/** Material: the Kanban "Boards" list, a checked board and the rest, each with a "…" menu. */
export const Boards = () => (
  <div style={panel}>
    <ListRow
      icon="check_circle"
      iconFilled
      title="Default"
      subtitle="default · 4 tasks"
      trailing={more}
      onClick={() => {}}
    />
    <ListRow
      icon="radio_button_unchecked"
      title="Ops"
      subtitle="ops · 1 tasks"
      trailing={more}
      onClick={() => {}}
    />
    <ListRow
      icon="radio_button_unchecked"
      title="Platform migration"
      subtitle="platform-migration · 12 tasks"
      trailing={more}
      onClick={() => {}}
    />
  </div>
);

/** Material: a worker row with a long wrapping subtitle, a selected row, a switch, a spinner and a disabled row. */
export const Trailing = () => (
  <div style={panel}>
    <ListRow
      title="Migrate webhooks to v2 signing"
      subtitle="t_run · run #7 · coder · started 3 min ago · heartbeat 20 s ago"
      trailing={more}
      onClick={() => {}}
    />
    <ListRow
      icon="memory"
      title="Memory provider"
      subtitle="honcho"
      selected
      onClick={() => {}}
    />
    <ListRow
      icon="notifications"
      title="Reply notifications"
      trailing={<Switch checked label="Reply notifications" />}
    />
    <ListRow
      icon="sync"
      title="Checking the server"
      trailing={<Spinner size={20} />}
    />
    <ListRow
      icon="extension"
      title="Achievements"
      subtitle="Turned off on this server"
      disabled
    />
  </div>
);

/** Apple: rows stacked as siblings form one inset grouped list, with disclosure chevrons, an Apple switch and a tag. */
export const AppleGrouped = () => (
  <HermesProvider platform="apple" style={{ ...panel, padding: "16px 0" }}>
    <div>
      <ListRow
        icon="tune"
        title="Helper models"
        subtitle="6 task slots"
        disclosure
        onClick={() => {}}
      />
      <ListRow icon="extension" title="Plugins" disclosure onClick={() => {}} />
      <ListRow
        icon="hub"
        title="MCP servers"
        trailing={<Badge>3</Badge>}
        disclosure
        onClick={() => {}}
      />
      <ListRow
        icon="notifications"
        title="Reply notifications"
        trailing={<Switch checked label="Reply notifications" />}
      />
    </div>
  </HermesProvider>
);

/** Apple boards list: the checked board, a row menu, then the same list ungrouped (`grouped={false}`) as in a sheet. */
export const AppleBoards = () => (
  <HermesProvider platform="apple" style={{ ...panel, padding: "16px 0" }}>
    <div>
      <ListRow
        icon="check_circle"
        iconFilled
        title="Default"
        subtitle="default · 4 tasks"
        trailing={more}
        onClick={() => {}}
      />
      <ListRow
        icon="radio_button_unchecked"
        title="Ops"
        subtitle="ops · 1 tasks"
        trailing={more}
        onClick={() => {}}
      />
    </div>
    <div style={{ marginTop: 16 }}>
      <ListRow
        grouped={false}
        icon="sync"
        title="Checking the server"
        trailing={<Spinner size={20} />}
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ display: "flex", gap: 16, padding: 16, borderRadius: 14 }}
  >
    <div style={panel}>
      <ListRow
        icon="check_circle"
        iconFilled
        title="Default"
        subtitle="default · 4 tasks"
        trailing={more}
        onClick={() => {}}
      />
      <ListRow
        icon="radio_button_unchecked"
        title="Ops"
        subtitle="ops · 1 tasks"
        selected
        trailing={more}
        onClick={() => {}}
      />
    </div>
    <HermesProvider
      theme="dark"
      platform="apple"
      style={{ ...panel, padding: "16px 0" }}
    >
      <div>
        <ListRow
          icon="tune"
          title="Helper models"
          disclosure
          onClick={() => {}}
        />
        <ListRow
          icon="notifications"
          title="Reply notifications"
          trailing={<Switch checked label="Reply notifications" />}
        />
      </div>
    </HermesProvider>
  </HermesProvider>
);
