import { Icon } from "../Icon/Icon";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import {
  cx,
  useGroupedChrome,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./GroupedChoiceRow.css";

export interface GroupedChoiceRowProps {
  /** The option's name: "Built-in", "holographic", "compressor", "System". */
  title: string;
  /** One muted line under it: "Remembers things with holographic." */
  subtitle?: string;
  /** Muted text right after the title: "Ready", "Default". */
  meta?: string;
  /** A warning line, such as why it cannot be picked: "Unavailable". */
  warning?: string;
  /** This option is the picked one. */
  checked?: boolean;
  /** The row was clicked: pick this option. */
  onSelect?: () => void;
  /** Cannot be picked: dimmed, no click. */
  disabled?: boolean;
  /**
   * `apple` (iOS and Mac): a check mark in the system blue at the trailing
   * edge of the picked row, nothing on the others. `material`: a radio
   * button at the leading edge (a 20px ring, filled dot when picked), so the
   * section needs `dividerIndent="choice"`. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * One option of a choice in a `GroupedSection` (memory provider, context
 * engine, theme, a model in the picker): the rows of one choice sit in one
 * section with `dividerIndent="choice"`, exactly one of them `checked`.
 */
export function GroupedChoiceRow({
  title,
  subtitle,
  meta,
  warning,
  checked = false,
  onSelect,
  disabled = false,
  platform,
  device,
}: GroupedChoiceRowProps) {
  const chrome = useGroupedChrome(platform, device);
  const apple = chrome !== "material";
  const mark = apple ? (
    <span className="h-choice-check" aria-hidden="true">
      {checked ? (
        <Icon
          name="check"
          apple="checkmark"
          size={chrome === "mac" ? 14 : 18}
        />
      ) : null}
    </span>
  ) : (
    <span
      className={cx("h-choice-radio", checked && "h-choice-radio--checked")}
      aria-hidden="true"
    />
  );
  return (
    <div
      className="h-choice-row"
      role="radio"
      aria-checked={checked}
      aria-disabled={disabled}
    >
      <GroupedRow
        title={title}
        subtitle={subtitle}
        meta={meta}
        warning={warning}
        leading={apple ? undefined : mark}
        trailing={apple ? mark : undefined}
        chevron={false}
        disabled={disabled}
        onClick={disabled ? undefined : (onSelect ?? (() => {}))}
        platform={platform}
        device={device}
      />
    </div>
  );
}
