import { HermesProvider, ImageViewerScreen } from "@hermes-app/ui";

/** A stand-in for the chart a user attached: a small bar chart on white. */
const chart =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="480" height="300" viewBox="0 0 480 300">
      <rect width="480" height="300" fill="#ffffff"/>
      <text x="24" y="36" font-family="sans-serif" font-size="16" font-weight="600" fill="#18181b">Backup duration (min)</text>
      <line x1="40" y1="260" x2="456" y2="260" stroke="#d4d4d8"/>
      <rect x="64" y="150" width="40" height="110" fill="#52525b"/>
      <rect x="128" y="120" width="40" height="140" fill="#52525b"/>
      <rect x="192" y="170" width="40" height="90" fill="#52525b"/>
      <rect x="256" y="90" width="40" height="170" fill="#52525b"/>
      <rect x="320" y="140" width="40" height="120" fill="#52525b"/>
      <rect x="384" y="70" width="40" height="190" fill="#b91c1c"/>
    </svg>`,
  );

const phone = {
  width: 360,
  height: 560,
  border: "1px solid var(--h-border)",
} as const;

/** With Save: Material (left) and Apple (right, xmark and arrow-down-to-line glyphs, 17px title). */
export const WithSave = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={phone}>
      <ImageViewerScreen
        name="backup-duration.png"
        src={chart}
        onSave={() => {}}
      />
    </div>
    <HermesProvider platform="apple">
      <div style={phone}>
        <ImageViewerScreen
          name="backup-duration.png"
          src={chart}
          onSave={() => {}}
        />
      </div>
    </HermesProvider>
  </div>
);

/** View only (no Save where the platform cannot save) and an image that cannot be drawn. */
export const ViewOnlyAndBroken = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={phone}>
      <ImageViewerScreen name="backup-duration.png" src={chart} />
    </div>
    <div style={phone}>
      <ImageViewerScreen
        name="IMG_20260920_153012_034.png"
        broken
        onSave={() => {}}
      />
    </div>
  </div>
);

/** Desktop window, dark theme: the viewer stays black. */
export const DesktopDark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...phone, width: 720, height: 480 }}>
      <ImageViewerScreen
        name="backup-duration.png"
        src={chart}
        onSave={() => {}}
      />
    </div>
  </HermesProvider>
);
