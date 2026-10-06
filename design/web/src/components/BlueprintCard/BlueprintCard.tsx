import { Icon } from "../Icon/Icon";
import { cx } from "../../platform";
import "./BlueprintCard.css";

/** A template for a scheduled task that the server offers ("blueprint"). */
export interface BlueprintItem {
  /** Stable key, e.g. `morning-brief`. */
  key: string;
  /** Card title: "Morning briefing". */
  title: string;
  /** What it does, cut after three lines: "A short daily briefing". */
  description?: string;
  /** Category the gallery filters by, lowercase: `daily`, `email`. */
  category?: string;
  /** The schedule in words, muted at the bottom: "daily at 08:00". */
  schedule?: string;
}

export interface BlueprintCardProps {
  /** The blueprint to show. */
  blueprint: BlueprintItem;
  /**
   * `template` (default): the gallery's 260px card with title, description
   * and schedule. `custom`: the full-width "Custom task · Start from scratch"
   * row with a leading "+", which opens the empty job form.
   */
  variant?: "template" | "custom";
  /** The card was pressed: open the blueprint's form. */
  onClick?: () => void;
}

/**
 * A card in the "New scheduled task" gallery: an outlined 14px-radius card
 * per blueprint, laid out in a wrapping row of 260px cards, under one
 * full-width `custom` card. Same on every platform, as in the app.
 */
export function BlueprintCard({
  blueprint,
  variant = "template",
  onClick,
}: BlueprintCardProps) {
  const custom = variant === "custom";
  return (
    <div
      className={cx("h-blueprint-card", custom && "h-blueprint-card--custom")}
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
      {custom ? <Icon name="add" size={24} /> : null}
      <div className="h-blueprint-card__text">
        <div className="h-blueprint-card__title">{blueprint.title}</div>
        {blueprint.description ? (
          <div className="h-blueprint-card__description">
            {blueprint.description}
          </div>
        ) : null}
        {blueprint.schedule && !custom ? (
          <div className="h-blueprint-card__schedule">{blueprint.schedule}</div>
        ) : null}
      </div>
    </div>
  );
}
