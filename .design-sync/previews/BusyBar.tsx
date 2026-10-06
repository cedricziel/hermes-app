import { BusyBar, HermesProvider } from "@hermes-app/ui";

const pane = {
  width: 360,
  display: "flex",
  flexDirection: "column",
  gap: 8,
} as const;

export const Indeterminate = () => (
  <div style={pane}>
    <div className="h-body-md">Installing web-scraper…</div>
    <BusyBar label="Installing web-scraper" />
  </div>
);

export const Progress = () => (
  <div style={pane}>
    <div className="h-body-md">Updating hub skills · 3 of 5</div>
    <BusyBar value={0.6} label="Updating hub skills" />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <div className="h-body-md">Installing web-scraper…</div>
      <BusyBar label="Installing web-scraper" />
      <BusyBar value={0.35} label="Updating hub skills" />
    </div>
  </HermesProvider>
);
