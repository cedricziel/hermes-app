import { Badge } from "../Badge/Badge";
import { Icon } from "../Icon/Icon";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "../SkillRow/SkillRow.css";

/** How far the skills hub vouches for a skill. */
export type HubTrust = "builtin" | "trusted" | "community";

/** A skill on the skills hub, installed or not. */
export interface HubSkill {
  /** Skill name: "web-scraper". */
  name: string;
  /** What it does: "Scrape pages into markdown." Two lines at most. */
  description?: string;
  /** `builtin` "Official" (a filled badge), `trusted` "Trusted", `community` "Community". */
  trust: HubTrust;
  /** Hub tags; the first three show as "#web". */
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
  /** It is installed on the profile: a check instead of the chevron, and the row opens the installed skill. */
  installed?: boolean;
  /** The row was pressed: open the hub skill (preview and scan) or the installed skill. */
  onClick?: () => void;
  /** `apple`: the iOS type ramp and CupertinoIcons. Inherits the provider's platform. */
  platform?: Platform;
}

/**
 * One skill in the Skills screen's Discover tab: the name in semibold, up to
 * two lines of description, a trust badge and up to three #tags, with a
 * check when it is installed and a chevron otherwise. Stack rows under a
 * `SectionHeader` ("Featured", "Official").
 */
export function HubSkillRow({
  skill,
  installed = false,
  onClick,
  platform,
}: HubSkillRowProps) {
  const resolved = usePlatform(platform);
  return (
    <PlatformScope platform={resolved}>
      <div
        className={cx(
          "h-skill-row",
          resolved === "apple" && "h-skill-row--apple",
        )}
        role="button"
        tabIndex={0}
        onClick={onClick}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            onClick?.();
          }
        }}
      >
        <div className="h-skill-row__body">
          <div className="h-skill-row__name">{skill.name}</div>
          {skill.description ? (
            <div className="h-skill-row__description h-skill-row__description--two">
              {skill.description}
            </div>
          ) : null}
          <div className="h-skill-row__meta">
            <Badge tone={skill.trust === "builtin" ? "strong" : "neutral"}>
              {hubTrustLabels[skill.trust]}
            </Badge>
            {(skill.tags ?? []).slice(0, 3).map((tag) => (
              <span key={tag} className="h-skill-row__tag">
                #{tag}
              </span>
            ))}
          </div>
        </div>
        <span className="h-skill-row__trailing">
          {installed ? (
            <Icon
              name="check_circle"
              size={24}
              label="Installed"
              className="h-skill-row__installed"
            />
          ) : (
            <Icon
              name="chevron_right"
              size={24}
              className="h-skill-row__chevron"
            />
          )}
        </span>
      </div>
    </PlatformScope>
  );
}
