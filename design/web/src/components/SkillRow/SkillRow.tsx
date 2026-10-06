import { Badge } from "../Badge/Badge";
import { Switch } from "../Switch/Switch";
import type { Platform } from "../../platform";
import { SkillRowShell } from "./SkillRowShell";

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
  /** How often the agent used it; shown as "used 14×" when above 0. */
  usage?: number;
}

export const skillSourceLabels: Record<SkillSource, string> = {
  hub: "Hub",
  bundled: "Bundled",
  agent: "Agent",
};

export interface SkillRowProps {
  /** The skill to show. */
  skill: Skill;
  /** The row was pressed: open the skill. */
  onClick?: () => void;
  /** The switch was flipped to this value. */
  onEnabledChange?: (enabled: boolean) => void;
  /** `apple`: the iOS type ramp and the 51x31 toggle. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * One installed skill on the Skills screen: the name in semibold, its
 * description on one line, a source badge (Hub, Bundled, Agent) with the
 * usage count, and an enabled switch. A switched-off skill dims its text.
 * Stack rows under a category `SectionHeader`.
 */
export function SkillRow({
  skill,
  onClick,
  onEnabledChange,
  platform,
}: SkillRowProps) {
  return (
    <SkillRowShell
      name={skill.name}
      description={skill.description}
      off={!skill.enabled}
      platform={platform}
      onClick={onClick}
      meta={
        <>
          <Badge>{skillSourceLabels[skill.source]}</Badge>
          {skill.usage ? (
            <span className="h-label-sm h-muted">used {skill.usage}×</span>
          ) : null}
        </>
      }
      trailing={
        <Switch
          checked={skill.enabled}
          label={`${skill.name} enabled`}
          onClick={(e) => e.stopPropagation()}
          onChange={onEnabledChange}
        />
      }
    />
  );
}
