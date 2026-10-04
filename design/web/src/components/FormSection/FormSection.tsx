import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { cx } from "../../platform";
import "./FormSection.css";

export interface FormSectionProps {
  /** The section's heading: "When", "Priority", "What time?". Leave out for a block of fields without one. */
  title?: string;
  /**
   * `title` (default): a 14px semibold heading, as the job form's "When" and
   * a blueprint's slot labels. `label`: a 14px medium label, as the Kanban
   * task form's "Model", "Priority" and "Start as".
   */
  titleStyle?: "title" | "label";
  /** Adds " (optional)" after the title, as blueprint slots do. */
  optional?: boolean;
  /** Muted hint under the content: "A file in the profile's scripts folder". */
  helper?: string;
  /** Red error under the content, shown with the helper. */
  error?: string;
  /**
   * The section folds open and shut under a full-width row with a chevron,
   * like the job form's "Advanced" (Flutter's ExpansionTile). The content is
   * shown only while `open`.
   */
  collapsible?: boolean;
  /** With `collapsible`: the section is unfolded. */
  open?: boolean;
  /** With `collapsible`: the heading row was pressed. */
  onToggle?: () => void;
  /** Gap between the children, in px (12 by default). */
  gap?: number;
  /** The section's fields: `TextField`, `SelectField`, a row of `Chip`s, a `Button`, a `ModelPill`. */
  children?: ReactNode;
}

/**
 * One block of a form screen: an optional heading, the fields under it, and
 * a helper or error line. Stack several in a column with 20px between them
 * for a whole form (job form, Kanban task form, blueprint form). Forms in the
 * app are Material on every platform, so this has no `platform` prop; the
 * controls inside (`Switch`, `Spinner`) follow the platform on their own.
 */
export function FormSection({
  title,
  titleStyle = "title",
  optional = false,
  helper,
  error,
  collapsible = false,
  open = false,
  onToggle,
  gap = 12,
  children,
}: FormSectionProps) {
  const heading = title && (optional ? `${title} (optional)` : title);
  const shown = !collapsible || open;
  return (
    <section className="h-form-section">
      {heading && collapsible ? (
        <button
          type="button"
          className="h-form-section__toggle"
          aria-expanded={open}
          onClick={onToggle}
        >
          <span>{heading}</span>
          <Icon
            name={open ? "expand_less" : "expand_more"}
            apple={false}
            size={24}
          />
        </button>
      ) : heading ? (
        <div
          className={cx(
            "h-form-section__title",
            titleStyle === "label" && "h-form-section__title--label",
          )}
        >
          {heading}
        </div>
      ) : null}
      {shown ? (
        <>
          {children ? (
            <div className="h-form-section__body" style={{ gap }}>
              {children}
            </div>
          ) : null}
          {helper ? (
            <div className="h-form-section__helper">{helper}</div>
          ) : null}
          {error ? (
            <div className="h-form-section__error" role="alert">
              {error}
            </div>
          ) : null}
        </>
      ) : null}
    </section>
  );
}
