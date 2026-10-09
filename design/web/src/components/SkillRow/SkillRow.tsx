import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import type { AppleDevice, Platform } from "../../platform";

/** Where an installed skill came from. */
export type SkillSource = "hub" | "bundled" | "agent";

/** A skill installed on a profile. */
export interface Skill {
  /** Skill name, e.g. "pr-review". */
  name: string;
  /** One line on what it is for: "Review a pull request". */
  description?: string;
  /** Category it is listed under: "github", "devops". */
  category?: string;
  /** `hub` installed from the skills hub, `bundled` shipped with Hermes, `agent` written by the agent (the only kind the app can edit). */
  source: SkillSource;
  /** The agent may load it. */
  enabled: boolean;
  /** How often the agent used it: "used once", "used 14 times" in the subtitle when above 0. */
  usage?: number;
}

export const skillSourceLabels: Record<SkillSource, string> = {
  hub: "Hub",
  bundled: "Bundled",
  agent: "Agent",
};

/** "Read Apple Notes · Bundled · used 14 times", as the app's `skillSubtitle`. */
function skillSubtitle(skill: Skill) {
  const usage = skill.usage ?? 0;
  return [
    skill.description,
    skillSourceLabels[skill.source],
    usage === 1 ? "used once" : usage > 1 ? `used ${usage} times` : null,
  ]
    .filter(Boolean)
    .join(" · ");
}

export interface SkillRowProps {
  /** The skill to show. */
  skill: Skill;
  /** The row was pressed: open the skill. The switch stays its own control. */
  onClick?: () => void;
  /** The switch was flipped to this value. */
  onEnabledChange?: (enabled: boolean) => void;
  /** `apple`: the iOS row (17px title, 15px subtitle, the 51x31 toggle), or on a Mac the 13px row and small 36x22 toggle. `material`: a 16px row with the Material switch. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited from `SettingsScaffold` or `GroupedSection`, else touch. */
  device?: AppleDevice;
}

/**
 * One installed skill on the Skills screen: a `GroupedSwitchRow` with the
 * name over "description · source · used N times" (one line, cut with an
 * ellipsis) and its enabled switch. Stack a category's rows in one
 * `GroupedSection` headed by the category.
 */
export function SkillRow({
  skill,
  onClick,
  onEnabledChange,
  platform,
  device,
}: SkillRowProps) {
  return (
    <GroupedSwitchRow
      title={skill.name}
      subtitle={skillSubtitle(skill)}
      checked={skill.enabled}
      onChange={onEnabledChange}
      onClick={onClick}
      platform={platform}
      device={device}
    />
  );
}
