import { PillSegmentedControl } from "../PillSegmentedControl/PillSegmentedControl";
import { SegmentedControl } from "../SegmentedControl/SegmentedControl";
import {
  cx,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { metricsClass } from "../../grouped";
import "./GroupedSegmentedRow.css";

export interface GroupedSegmentedRowProps {
  /** The choices, in order: `["Low", "Medium", "High"]`, `["Once", "Interval", "Cron"]`. */
  labels: string[];
  /** Index of the picked choice. */
  value: number;
  /** Called with the index the user picks. */
  onChange?: (index: number) => void;
  /** Accessible name: "Reasoning effort". */
  label?: string;
  /**
   * `apple`: the sliding segmented control across the row (13px labels; on
   * a Mac 12px). `material`: a
   * `PillSegmentedControl` across the row. The row has the group's side
   * padding and 8px above and below. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited, else `touch`. */
  device?: AppleDevice;
}

/**
 * A choice between a few options across a group's row: a reasoning effort,
 * a schedule kind. For a longer list use `GroupedChoiceRow`s or a
 * `GroupedMenuRow`.
 */
export function GroupedSegmentedRow({
  labels,
  value,
  onChange,
  label,
  platform,
  device,
}: GroupedSegmentedRowProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  return (
    <div className={cx("h-grouped-segmented", metricsClass(chrome))}>
      {chrome === "material" ? (
        <PillSegmentedControl
          labels={labels}
          value={value}
          onChange={onChange}
          label={label}
        />
      ) : (
        <SegmentedControl
          labels={labels}
          value={value}
          onChange={onChange}
          label={label}
          platform="apple"
          size="inline"
          className={cx(chrome === "mac" && "h-grouped-segmented__mac")}
        />
      )}
    </div>
  );
}
