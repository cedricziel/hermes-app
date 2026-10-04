import { useId, useState } from "react";
import { Icon } from "../Icon/Icon";
import { Menu, MenuAnchor } from "../Menu/Menu";
import { cx, type AppleDevice } from "../../platform";
import "../TextField/TextField.css";
import "./SelectField.css";

export interface SelectFieldProps {
  /** Label above the field, as on `TextField`: "Deliver results to", "Assignee", "Model". */
  label?: string;
  /** The value shown, already labelled: "Telegram", "Auto (triage picks)", "claude-opus-4". */
  value?: string;
  /** Muted text when there is no `value`: "Profile default", "Choose…". */
  placeholder?: string;
  /** Hint below the field: "Anthropic", "Leave empty for the profile default". */
  helper?: string;
  /** Error below the field; also turns the border red. */
  error?: string;
  /** Monospace value, for model ids and paths. */
  mono?: boolean;
  /** Greyed out and not pressable. */
  disabled?: boolean;
  /**
   * The choices of a dropdown. With them, pressing the field opens a `Menu`
   * under it (the current `value` checked). Leave them out for a field that
   * opens a picker of its own, such as the job form's model, and handle
   * `onClick`.
   */
  options?: string[];
  /** Draw the menu open, for previews. */
  defaultOpen?: boolean;
  /** Under `platform="apple"`, which menu the options open in: `touch` (iOS pull-down) or `mac` (compact Mac menu). Inherited from the enclosing `AppShell`, else `mac`; pass `touch` for an iPhone form. */
  device?: AppleDevice;
  /** An option was picked from the menu. */
  onChange?: (value: string) => void;
  /** The field was pressed (also called before the menu opens). */
  onClick?: () => void;
}

/**
 * A field that shows a choice and opens a list or a picker: the app's
 * `DropdownButtonFormField` and the job form's model field, drawn with an
 * outlined `TextField`'s frame (its CSS classes) with a trailing chevron. Same on every platform, as in
 * the app; its `Menu` follows the platform.
 */
export function SelectField({
  label,
  value,
  placeholder,
  helper,
  error,
  mono = false,
  disabled = false,
  options,
  defaultOpen = false,
  device,
  onChange,
  onClick,
}: SelectFieldProps) {
  const id = useId();
  const [open, setOpen] = useState(defaultOpen);
  const note = error || helper;
  return (
    <div className={cx("h-field", disabled && "h-select-field--off")}>
      {label ? (
        <label className="h-field__label" htmlFor={id}>
          {label}
        </label>
      ) : null}
      <MenuAnchor>
        <button
          id={id}
          type="button"
          className={cx(
            "h-field__box h-field__box--outlined h-select-field__box",
            error && "h-field__box--error",
          )}
          disabled={disabled}
          aria-haspopup={options ? "listbox" : "dialog"}
          onClick={() => {
            onClick?.();
            if (options) setOpen((o) => !o);
          }}
        >
          <span
            className={cx(
              "h-select-field__value",
              !value && "h-select-field__value--placeholder",
              mono && "h-mono",
            )}
          >
            {value || placeholder}
          </span>
          <Icon name="expand_more" apple={false} size={24} />
        </button>
        {options && open ? (
          <Menu
            align="start"
            device={device}
            label={label ?? "Options"}
            style={{ minWidth: 220 }}
            items={options.map((o) => ({
              label: o,
              value: o,
              checked: o === value,
            }))}
            onSelect={(item) => {
              setOpen(false);
              if (item.value) onChange?.(item.value);
            }}
          />
        ) : null}
      </MenuAnchor>
      {note ? (
        <div className={error ? "h-field__error" : "h-field__helper"}>
          {note}
        </div>
      ) : null}
    </div>
  );
}
