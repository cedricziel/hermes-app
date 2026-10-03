import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import "./StateMessage.css";

export interface StateMessageProps {
  /** Material Symbols icon name, drawn at 40px above the title. */
  icon?: string;
  title: string;
  detail?: string;
  /** A button below the text, such as Retry. */
  action?: ReactNode;
}

/** A centered message for a screen with nothing to show: empty, failed to load, or not available on this server. */
export function StateMessage({
  icon,
  title,
  detail,
  action,
}: StateMessageProps) {
  return (
    <div className="h-state">
      {icon ? <Icon name={icon} size={40} /> : null}
      <div className="h-state__title">{title}</div>
      {detail ? <div className="h-state__detail">{detail}</div> : null}
      {action ? <div className="h-state__action">{action}</div> : null}
    </div>
  );
}
