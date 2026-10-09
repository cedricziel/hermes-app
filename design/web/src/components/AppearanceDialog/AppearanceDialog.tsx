import { GroupedChoiceRow } from "../GroupedChoiceRow/GroupedChoiceRow";
import { GroupedDialog } from "../GroupedDialog/GroupedDialog";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import type { AppleDevice, Platform } from "../../platform";

/** The app's theme modes. */
export type ThemeMode = "system" | "light" | "dark";

/** What each theme mode is called in the settings (the app's `themeModeLabels`). */
export const themeModeLabels: Record<ThemeMode, string> = {
  system: "Follow system",
  light: "Light",
  dark: "Dark",
};

export interface AppearanceDialogProps {
  /** The theme in use; its row is checked. */
  mode: ThemeMode;
  /** Another theme was picked. The app applies it at once and keeps the dialog open. */
  onChange?: (mode: ThemeMode) => void;
  /** Done (Apple), or the barrier or Escape. */
  onDone?: () => void;
  /** Draw the dialog alone, without the dimmed barrier, for a catalog cell. */
  inline?: boolean;
  /** `apple`: a blue check after the picked theme. `material`: a radio before each theme. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * The app's Appearance dialog (`showAppearanceDialog`): a `GroupedDialog`
 * titled "Appearance" holding one group of three choice rows, Follow
 * system, Light and Dark.
 */
export function AppearanceDialog({
  mode,
  onChange,
  onDone,
  inline,
  platform,
  device,
}: AppearanceDialogProps) {
  return (
    <GroupedDialog
      title="Appearance"
      onDone={onDone}
      inline={inline}
      platform={platform}
      device={device}
    >
      <GroupedSection dividerIndent="choice" label="Theme">
        {(Object.keys(themeModeLabels) as ThemeMode[]).map((m) => (
          <GroupedChoiceRow
            key={m}
            title={themeModeLabels[m]}
            checked={m === mode}
            onSelect={() => onChange?.(m)}
          />
        ))}
      </GroupedSection>
    </GroupedDialog>
  );
}
