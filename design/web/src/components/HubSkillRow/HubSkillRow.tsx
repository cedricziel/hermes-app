import { GroupedRow } from "../GroupedRow/GroupedRow";
import type { AppleDevice, Platform } from "../../platform";

/** How far the skills hub vouches for a skill. */
export type HubTrust = "builtin" | "trusted" | "community";

/** A skill on the skills hub, installed or not. */
export interface HubSkill {
  /** Skill name: "web-scraper". */
  name: string;
  /** What it does, after the trust label in the subtitle: "Scrape pages into markdown." */
  description?: string;
  /** `builtin` "Official", `trusted` "Trusted", `community` "Community"; first in the subtitle. */
  trust: HubTrust;
  /** Hub tags: "web". Shown on the skill's own screen, not the row. */
  tags?: string[];
}

export const hubTrustLabels: Record<HubTrust, string> = {
  builtin: "Official",
  trusted: "Trusted",
  community: "Community",
};

export interface HubSkillRowProps {
  /** The hub skill to show. */
  skill: HubSkill;
  /** It is installed on the profile: "Installed" in muted text before the chevron, and the row opens the installed skill. */
  installed?: boolean;
  /** The row was pressed: open the hub skill (preview and scan) or the installed skill. */
  onClick?: () => void;
  /** `apple`: the iOS or Mac grouped row with a disclosure chevron. `material`: the Material row (with a chevron too, as the app draws it). Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited from `SettingsScaffold` or `GroupedSection`, else touch. */
  device?: AppleDevice;
}

/**
 * One skill in the Skills screen's Discover tab: a `GroupedRow` with the
 * name over "Community · Scrape pages into markdown." and a chevron, with
 * "Installed" before it when the profile has it. Stack rows in a
 * `GroupedSection` ("Featured", "Official", "Results").
 */
export function HubSkillRow({
  skill,
  installed = false,
  onClick,
  platform,
  device,
}: HubSkillRowProps) {
  return (
    <GroupedRow
      title={skill.name}
      subtitle={[hubTrustLabels[skill.trust], skill.description]
        .filter(Boolean)
        .join(" · ")}
      value={installed ? "Installed" : undefined}
      chevron
      onClick={onClick}
      platform={platform}
      device={device}
    />
  );
}
