import { GroupedRow, GroupedTile } from "../GroupedRow/GroupedRow";
import { type AppleDevice, type Platform } from "../../platform";

/** A template for a scheduled task that the server offers ("blueprint"). */
export interface BlueprintItem {
  /** Stable key, e.g. `morning-brief`. */
  key: string;
  /** Row title: "Morning briefing". */
  title: string;
  /** What it does, the muted subtitle: "A short daily briefing". */
  description?: string;
  /** Category the gallery groups and filters by, lowercase: `daily`, `email`. */
  category?: string;
  /** The schedule in words, the smaller caption: "daily at 08:00". */
  schedule?: string;
}

export interface BlueprintCardProps {
  /** The blueprint to show. */
  blueprint: BlueprintItem;
  /**
   * `template` (default): a gallery row with the title, the description as
   * subtitle and the schedule as caption. `custom`: "Custom task · Start
   * from scratch" with a "+" in a leading `GroupedTile`, which opens the
   * empty job form; give its section `dividerIndent="tile"`.
   */
  variant?: "template" | "custom";
  /** The row was pressed: open the blueprint's form. */
  onClick?: () => void;
  /** iOS 17/15/13px, Mac 13/11/11px, Material 16/14/13px, with the disclosure chevron. Inherits the provider's platform. */
  platform?: Platform;
  device?: AppleDevice;
}

/**
 * A row of the "New scheduled task" gallery, a `GroupedRow` with a
 * chevron: one per blueprint inside its category's `GroupedSection`, and
 * the `custom` row in a group of its own on top. (It was a card before the
 * gallery became grouped sections; the name stays.)
 */
export function BlueprintCard({
  blueprint,
  variant = "template",
  onClick,
  platform,
  device,
}: BlueprintCardProps) {
  const custom = variant === "custom";
  return (
    <GroupedRow
      leading={
        custom ? (
          <GroupedTile icon="add" platform={platform} device={device} />
        ) : undefined
      }
      title={blueprint.title}
      subtitle={blueprint.description || undefined}
      caption={custom ? undefined : blueprint.schedule || undefined}
      onClick={onClick ?? (() => {})}
      platform={platform}
      device={device}
    />
  );
}
