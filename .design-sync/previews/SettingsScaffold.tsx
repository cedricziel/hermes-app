import {
  GroupedListView,
  GroupedRow,
  GroupedSection,
  GroupedSwitchRow,
  GroupedTextFieldRow,
  GroupedTile,
  GroupedValueRow,
  HermesProvider,
  SettingsScaffold,
  type SettingsBarAction,
} from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 560,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 420 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const noop = () => {};

const skillFilters = [
  { label: "All", selected: true },
  { label: "Enabled" },
  { label: "Disabled" },
  { label: "Bundled" },
  { label: "Hub" },
];
const profiles = [
  { label: "default", checked: true },
  { label: "work", checked: false },
];
const add: SettingsBarAction = { icon: "add", label: "New skill" };

const skills = (
  <GroupedListView>
    <GroupedSection header="Apple">
      <GroupedSwitchRow
        title="apple-notes"
        subtitle="Read and write Notes · Bundled"
        checked
        onChange={noop}
      />
      <GroupedSwitchRow
        title="imessage"
        subtitle="Send messages · Hub · used 3 times"
        checked={false}
        onChange={noop}
      />
    </GroupedSection>
    <GroupedSection header="DevOps">
      <GroupedSwitchRow
        title="docker-compose"
        subtitle="Run and inspect compose stacks · Bundled"
        checked
        onChange={noop}
      />
    </GroupedSection>
  </GroupedListView>
);

/** Skills on iPhone and Material: "+" in the bar, the profile as a subtitle menu, tabs (segmented / pill) and the search field with its filter button. */
export const TabsSearchAdd = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider key={platform} platform={platform} style={phone}>
        <SettingsScaffold
          title="Skills"
          subtitle="default"
          subtitleMenu={{ label: "Profile", items: profiles }}
          onBack={noop}
          actions={[add]}
          tabs={["Installed", "Discover"]}
          search={{ hint: "Search skills", filters: skillFilters }}
        >
          {skills}
        </SettingsScaffold>
      </HermesProvider>
    ))}
  </div>
);

/** Skills on a Mac: back button, title over "default · 3 skills", then tabs, search field and filter, a separator and "+" in the toolbar; the groups in the centred 600px column. */
export const MacToolbarTabs = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <SettingsScaffold
      device="mac"
      title="Skills"
      subtitle="default · 3 skills"
      onBack={noop}
      actions={[add]}
      tabs={["Installed", "Discover"]}
      search={{ hint: "Search", filters: skillFilters }}
    >
      {skills}
    </SettingsScaffold>
  </HermesProvider>
);

const mcpActions: SettingsBarAction[] = [
  {
    icon: "add",
    label: "Add",
    menu: [
      { label: "Browse the catalog", icon: "storefront" },
      { label: "Add a custom server", icon: "edit" },
    ],
    menuOpen: true,
  },
  { icon: "more_horiz", label: "More" },
];

const servers = (
  <GroupedListView>
    <GroupedSection
      dividerIndent="tile"
      footer="Changes apply from the next chat, not to one that is already running."
    >
      <GroupedSwitchRow
        title="github"
        leading={<GroupedTile>G</GroupedTile>}
        subtitle="https://api.githubcopilot.com/mcp/"
        caption="Remote · OAuth · 2 tools"
        checked
        onChange={noop}
        onClick={noop}
      />
      <GroupedSwitchRow
        title="filesystem"
        leading={<GroupedTile>F</GroupedTile>}
        subtitle="npx -y @acme/mcp-fs ~/notes"
        monospaceSubtitle
        warning="Sign in needed"
        checked={false}
        onChange={noop}
        onClick={noop}
      />
    </GroupedSection>
  </GroupedListView>
);

/** MCP servers: the "+" opens the Add menu (the iOS pull-down, the Material popup) beside "…". */
export const ListWithAddMenu = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider key={platform} platform={platform} style={phone}>
        <SettingsScaffold
          title="MCP servers"
          subtitle="work"
          onBack={noop}
          actions={mcpActions}
        >
          {servers}
        </SettingsScaffold>
      </HermesProvider>
    ))}
  </div>
);

const jobForm = (
  <GroupedListView>
    <GroupedSection header="Job">
      <GroupedTextFieldRow label="Name" defaultValue="Nightly backup" />
      <GroupedTextFieldRow
        label="Prompt"
        hint="What should Hermes do?"
        rows={3}
      />
    </GroupedSection>
    <GroupedSection header="Run" footer="Hermes runs the job on the server.">
      <GroupedValueRow
        title="Schedule"
        value="Every day at 03:00"
        onClick={noop}
      />
      <GroupedValueRow title="Model" value="Profile default" onClick={noop} />
    </GroupedSection>
  </GroupedListView>
);

/** A form: Cancel (iOS) or close (Material) leading, the title, and Save as the bar's text button. */
export const FormSaveCancel = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider key={platform} platform={platform} style={phone}>
        <SettingsScaffold
          title="New schedule"
          subtitle="default"
          onCancel={noop}
          formAction={{ label: "Save" }}
        >
          {jobForm}
        </SettingsScaffold>
      </HermesProvider>
    ))}
  </div>
);

/** The same form on a Mac: back button and the small filled Create button in the toolbar. */
export const MacForm = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <SettingsScaffold
      device="mac"
      title="New schedule"
      subtitle="default"
      onBack={noop}
      formAction={{ label: "Create" }}
    >
      {jobForm}
    </SettingsScaffold>
  </HermesProvider>
);

/** Dark, with the subtitle's profile menu open: Helper models on iPhone and Material. */
export const DarkSubtitleMenu = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        theme="dark"
        platform={platform}
        style={phone}
      >
        <SettingsScaffold
          title="Helper models"
          subtitle="default"
          subtitleMenu={{ label: "Profile", items: profiles, open: true }}
          onBack={noop}
        >
          <GroupedListView>
            <GroupedSection footer="Hermes runs side jobs on these models. Main model is claude-opus-4. Changes apply to new chats.">
              <GroupedValueRow
                title="Vision"
                value="Main model"
                onClick={noop}
              />
              <GroupedValueRow
                title="Chat titles"
                value="gemini-flash"
                onClick={noop}
              />
            </GroupedSection>
            <GroupedSection>
              <GroupedRow
                title="Mixture of agents"
                value="Default"
                onClick={noop}
              />
            </GroupedSection>
          </GroupedListView>
        </SettingsScaffold>
      </HermesProvider>
    ))}
  </div>
);
