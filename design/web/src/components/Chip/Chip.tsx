import type { ButtonHTMLAttributes } from "react";
import { Icon } from "../Icon/Icon";
import "./Chip.css";

export interface ChipProps extends Omit<
  ButtonHTMLAttributes<HTMLButtonElement>,
  "children"
> {
  label: string;
  /** Leading Material Symbols icon name (filters use `filter_list`). */
  icon?: string;
  /** Selected filter: filled `surface-high` with a check. */
  selected?: boolean;
  /** Shows a trailing close button and calls this when it is pressed (attachment chips). */
  onRemove?: () => void;
}

/** An outlined 32px chip for filters, starter options and attachments. */
export function Chip({
  label,
  icon,
  selected = false,
  onRemove,
  className,
  type = "button",
  ...rest
}: ChipProps) {
  const classes = ["h-chip", selected ? "h-chip--selected" : null, className]
    .filter(Boolean)
    .join(" ");
  return (
    <span className={classes}>
      <button type={type} className="h-chip__main" {...rest}>
        {selected ? (
          <Icon name="check" size={18} />
        ) : icon ? (
          <Icon name={icon} size={18} />
        ) : null}
        <span className="h-chip__label">{label}</span>
      </button>
      {onRemove ? (
        <button
          type="button"
          className="h-chip__remove"
          aria-label={`Remove ${label}`}
          onClick={onRemove}
        >
          <Icon name="close" size={16} />
        </button>
      ) : null}
    </span>
  );
}
