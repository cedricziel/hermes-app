import { GroupedRow, type GroupedRowProps } from "../GroupedRow/GroupedRow";
import { Switch } from "../Switch/Switch";
import { useGroupedChrome } from "../../platform";

export interface GroupedSwitchRowProps extends Omit<
  GroupedRowProps,
  "value" | "trailing" | "chevron" | "destructive"
> {
  /** On or off. */
  checked: boolean;
  /** Called with the new value when the switch is flipped. Leave out (or set `disabled`) to show a switch that cannot change. */
  onChange?: (checked: boolean) => void;
}

/**
 * A `GroupedRow` whose trailing control is a `Switch` named by the title:
 * "Enabled", a skill, a messaging platform. The Apple 51x31 toggle on iOS,
 * the small 36x22 toggle on a Mac, the Material switch on Material. With
 * `onClick` the row also opens details and the switch stays its own button.
 */
export function GroupedSwitchRow({
  checked,
  onChange,
  disabled,
  ...row
}: GroupedSwitchRowProps) {
  const chrome = useGroupedChrome(row.platform, row.device);
  return (
    <GroupedRow
      {...row}
      chevron={false}
      trailing={
        <Switch
          checked={checked}
          label={row.title}
          small={chrome === "mac"}
          disabled={disabled || !onChange}
          onChange={onChange}
        />
      }
    />
  );
}
