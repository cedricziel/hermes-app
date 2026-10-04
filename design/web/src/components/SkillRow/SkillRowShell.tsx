import type { ReactNode } from "react";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./SkillRow.css";

/** The pressable row SkillRow and HubSkillRow share: name, description, a meta line and a trailing control. */
export function SkillRowShell({
  name,
  description,
  twoLines = false,
  off = false,
  meta,
  trailing,
  onClick,
  platform,
}: {
  name: string;
  description?: string;
  /** Clamp the description at two lines instead of one. */
  twoLines?: boolean;
  /** Dim the name and description (a switched-off skill). */
  off?: boolean;
  meta: ReactNode;
  trailing: ReactNode;
  onClick?: () => void;
  platform?: Platform;
}) {
  const resolved = usePlatform(platform);
  return (
    <PlatformScope platform={resolved}>
      <div
        className={cx(
          "h-skill-row",
          resolved === "apple" && "h-skill-row--apple",
          off && "h-skill-row--off",
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
          <div className="h-skill-row__name">{name}</div>
          {description ? (
            <div
              className={cx(
                "h-skill-row__description",
                twoLines && "h-skill-row__description--two",
              )}
            >
              {description}
            </div>
          ) : null}
          <div className="h-skill-row__meta">{meta}</div>
        </div>
        <span className="h-skill-row__trailing">{trailing}</span>
      </div>
    </PlatformScope>
  );
}
