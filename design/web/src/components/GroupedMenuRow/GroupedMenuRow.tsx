import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import { Menu, useMenuState } from "../Menu/Menu";
import {
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./GroupedMenuRow.css";

export interface GroupedMenuRowProps {
  /** The setting's label: "Theme", "Priority", "Deliver to". */
  title: string;
  /** The choices, top to bottom: `["System", "Light", "Dark"]`. */
  options: string[];
  /** Index of the picked option; leave out while nothing is picked. */
  selected?: number;
  /** Called with the index the user picks. */
  onSelect?: (index: number) => void;
  /** The value shown while nothing is `selected`: "None". */
  placeholder?: string;
  /** A warning line under the label. */
  warning?: string;
  /** Draws the menu open, for previews; a click on the row also opens it. */
  open?: boolean;
  /**
   * The row is a `GroupedValueRow` (iOS: value and chevron; Mac: the
   * pop-up button; Material: label over value). Its menu, under the row's
   * trailing edge with the picked option checked, follows the platform: the
   * iOS pull-down, the compact Mac menu, the Material popup. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * A labelled value picked from a short menu of options in a group row:
 * the appearance's theme, a Kanban task's priority, a job's delivery.
 */
export function GroupedMenuRow({
  title,
  options,
  selected,
  onSelect,
  placeholder = "",
  warning,
  open: openProp = false,
  platform,
  device,
}: GroupedMenuRowProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const [open, setOpen] = useMenuState(openProp);
  const value = selected === undefined ? placeholder : options[selected];
  return (
    <div
      className="h-grouped-menu-row"
      onMouseDown={(e) => e.stopPropagation()}
    >
      <GroupedValueRow
        title={title}
        value={value ?? placeholder}
        warning={warning}
        onClick={() => setOpen((o) => !o)}
        platform={resolved}
        device={device}
      />
      {open ? (
        <Menu
          align="end"
          label={title}
          platform={resolved}
          device={chrome === "mac" ? "mac" : "touch"}
          className="h-grouped-menu-row__menu"
          items={options.map((label, i) => ({
            label,
            checked: i === selected,
          }))}
          onSelect={(_, i) => {
            setOpen(false);
            onSelect?.(i);
          }}
        />
      ) : null}
    </div>
  );
}
