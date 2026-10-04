import { Badge } from "../Badge/Badge";
import { Switch } from "../Switch/Switch";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./SkillRow.css";

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
  const resolved = usePlatform(platform);
  return (
    <PlatformScope platform={resolved}>
      <div
        className={cx(
          "h-skill-row",
          resolved === "apple" && "h-skill-row--apple",
          !skill.enabled && "h-skill-row--off",
        )}
        role="button"
        tabIndex={0}
        onClick={onClick}
        onKeyDown={(e) => {
          if (e.target !== e.currentTarget) return;
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            onClick?.();
          }
        }}
      >
        <div className="h-skill-row__body">
          <div className="h-skill-row__name">{skill.name}</div>
          {skill.description ? (
            <div className="h-skill-row__description">{skill.description}</div>
          ) : null}
          <div className="h-skill-row__meta">
            <Badge>{skillSourceLabels[skill.source]}</Badge>
            {skill.usage ? (
              <span className="h-skill-row__usage">used {skill.usage}×</span>
            ) : null}
          </div>
        </div>
        <Switch
          checked={skill.enabled}
          label={`${skill.name} enabled`}
          onClick={(e) => e.stopPropagation()}
          onChange={onEnabledChange}
        />
      </div>
    </PlatformScope>
  );
}
