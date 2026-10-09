import {
  HermesProvider,
  MacToolbar,
  SettingsSearchField,
} from "@hermes-app/ui";

const filters = [
  { label: "All", selected: true },
  { label: "Enabled" },
  { label: "Disabled" },
  { label: "Bundled" },
  { label: "Hub" },
];
const narrowed = filters.map((f) => ({
  label: f.label,
  selected: f.label === "Enabled",
}));

const column = {
  display: "flex",
  flexDirection: "column",
  gap: 12,
  width: 360,
  padding: 16,
} as const;

/** iPhone: the 36px field with the filter button inside; typed text with the clear button; a filter in effect marks the button. */
export const IPhone = () => (
  <HermesProvider platform="apple" style={column}>
    <SettingsSearchField hint="Search skills" filters={filters} />
    <SettingsSearchField query="docker" filters={filters} />
    <SettingsSearchField hint="Search skills" filters={narrowed} />
    <SettingsSearchField hint="Search catalog" />
  </HermesProvider>
);

/** Material: the 44px pill, the same three states and one without filters. */
export const Material = () => (
  <HermesProvider style={column}>
    <SettingsSearchField hint="Search skills" filters={filters} />
    <SettingsSearchField query="docker" filters={filters} />
    <SettingsSearchField hint="Search skills" filters={narrowed} />
    <SettingsSearchField hint="Search catalog" />
  </HermesProvider>
);

/** Mac: the toolbar search field with the filter toolbar button beside it, its menu open with "Enabled" checked. */
export const Mac = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    style={{ width: 640, height: 230, border: "1px solid var(--h-border)" }}
  >
    <MacToolbar
      title="Skills"
      subtitle="default · 3 skills"
      actions={
        <SettingsSearchField
          device="mac"
          hint="Search skills"
          query="git"
          filters={narrowed}
          filterMenuOpen
        />
      }
    />
  </HermesProvider>
);

/** The filter menu open on iPhone (the pull-down) and Material (the popup). */
export const FilterMenu = () => (
  <HermesProvider style={{ display: "flex", gap: 16, height: 300 }}>
    <HermesProvider platform="apple" style={column}>
      <SettingsSearchField
        hint="Search skills"
        filters={narrowed}
        filterMenuOpen
      />
    </HermesProvider>
    <HermesProvider style={column}>
      <SettingsSearchField
        hint="Search skills"
        filters={narrowed}
        filterMenuOpen
      />
    </HermesProvider>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ display: "flex", gap: 16 }}>
    <HermesProvider theme="dark" platform="apple" style={column}>
      <SettingsSearchField hint="Search skills" filters={filters} />
      <SettingsSearchField query="docker" filters={narrowed} />
    </HermesProvider>
    <HermesProvider theme="dark" style={column}>
      <SettingsSearchField hint="Search skills" filters={filters} />
      <SettingsSearchField query="docker" filters={narrowed} />
    </HermesProvider>
  </HermesProvider>
);
