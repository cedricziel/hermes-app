import {
  GroupedFooter,
  GroupedSection,
} from "../GroupedSection/GroupedSection";
import { GroupedMenuRow } from "../GroupedMenuRow/GroupedMenuRow";
import { GroupedSegmentedRow } from "../GroupedSegmentedRow/GroupedSegmentedRow";
import { GroupedTextFieldRow } from "../GroupedTextFieldRow/GroupedTextFieldRow";
import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import { cx, type AppleDevice, type Platform } from "../../platform";
import "./SchedulePicker.css";

/** How a job's schedule is entered. */
export type ScheduleMode = "every" | "daily" | "weekly" | "once" | "cron";

/** A unit of an `every` schedule. */
export type ScheduleEveryUnit = "minutes" | "hours" | "days";

const modes: ScheduleMode[] = ["every", "daily", "weekly", "once", "cron"];
const modeLabels = ["Every", "Daily", "Weekly", "Once", "Cron"];
const units: ScheduleEveryUnit[] = ["minutes", "hours", "days"];
const week = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export interface SchedulePickerProps {
  /** The segment picked; it decides the rows under the control. */
  mode: ScheduleMode;
  /** `every`: the number typed, e.g. `30`. */
  amount?: string;
  /** `every`: the unit picked. */
  unit?: ScheduleEveryUnit;
  /** `daily`, `weekly`, `once`: the time, `08:00`. */
  time?: string;
  /** `weekly`: the days picked, as `Mon` … `Sun`. */
  days?: string[];
  /** `once`: the date, already formatted: "Oct 10, 2026". */
  date?: string;
  /** `cron`: the expression or phrase typed. */
  cron?: string;
  /** The next runs worked out from a valid schedule, the group's footer: "Oct 9, 2026 3:45 AM, Oct 9, 2026 4:45 AM, …". Without it a `cron` schedule says the server works it out on save. */
  nextRuns?: string;
  /** Draws the Unit menu open, for previews. */
  unitMenuOpen?: boolean;
  /** iOS, Mac and Material grouped rows, from the enclosing `GroupedListView`. Inherits the provider's platform. */
  platform?: Platform;
  device?: AppleDevice;
  /** A segment pressed. */
  onModeChange?: (mode: ScheduleMode) => void;
  /** `every`: the amount typed. */
  onAmountChange?: (amount: string) => void;
  /** `every`: a unit picked. */
  onUnitChange?: (unit: ScheduleEveryUnit) => void;
  /** `weekly`: a day toggled. */
  onDayToggle?: (day: string) => void;
  /** The Time row pressed (the app opens its time picker). */
  onPickTime?: () => void;
  /** `once`: the Date row pressed (the app opens its date picker). */
  onPickDate?: () => void;
  /** `cron`: the expression typed. */
  onCronChange?: (cron: string) => void;
}

/**
 * The "When" of the job form as a `GroupedSection` headed "When": a
 * `GroupedSegmentedRow` (Every, Daily, Weekly, Once, Cron), then the rows of
 * the mode picked: Every (a number field) and Unit (a menu row); a Time
 * value row; the seven day pills (Mon first, the picked ones filled with
 * the primary color) and Time; Date and Time; or a monospace Schedule
 * field. Under the group: the cron hint and the next runs as footers. Put
 * it in a `GroupedListView` between the form's other sections.
 */
export function SchedulePicker({
  mode,
  amount = "",
  unit = "minutes",
  time = "08:00",
  days = [],
  date,
  cron = "",
  nextRuns,
  unitMenuOpen,
  platform,
  device,
  onModeChange,
  onAmountChange,
  onUnitChange,
  onDayToggle,
  onPickTime,
  onPickDate,
  onCronChange,
}: SchedulePickerProps) {
  const timeRow = (
    <GroupedValueRow title="Time" value={time} onClick={() => onPickTime?.()} />
  );
  return (
    <>
      <GroupedSection header="When" platform={platform} device={device}>
        <GroupedSegmentedRow
          labels={modeLabels}
          value={modes.indexOf(mode)}
          label="When"
          onChange={(i) => onModeChange?.(modes[i])}
        />
        {mode === "every" ? (
          <GroupedTextFieldRow
            label="Every"
            type="number"
            value={amount}
            onChange={onAmountChange}
          />
        ) : null}
        {mode === "every" ? (
          <GroupedMenuRow
            title="Unit"
            options={units}
            selected={units.indexOf(unit)}
            open={unitMenuOpen}
            onSelect={(i) => onUnitChange?.(units[i])}
          />
        ) : null}
        {mode === "weekly" ? (
          <div className="h-schedule-picker__days">
            {week.map((d) => {
              const on = days.includes(d);
              return (
                <button
                  key={d}
                  type="button"
                  aria-pressed={on}
                  className={cx(
                    "h-schedule-picker__day",
                    on && "h-schedule-picker__day--on",
                  )}
                  onClick={() => onDayToggle?.(d)}
                >
                  {d}
                </button>
              );
            })}
          </div>
        ) : null}
        {mode === "once" ? (
          <GroupedValueRow
            title="Date"
            value={date ?? "Choose a date"}
            onClick={() => onPickDate?.()}
          />
        ) : null}
        {mode === "daily" || mode === "weekly" || mode === "once"
          ? timeRow
          : null}
        {mode === "cron" ? (
          <GroupedTextFieldRow
            label="Schedule"
            hint="0 9 * * 1-5"
            monospace
            value={cron}
            onChange={onCronChange}
          />
        ) : null}
      </GroupedSection>
      {mode === "cron" ? (
        <GroupedFooter platform={platform} device={device}>
          A five-field cron expression, for example 0 9 * * 1-5, or a phrase
          like every monday 9am.
        </GroupedFooter>
      ) : null}
      {nextRuns ? (
        <GroupedFooter platform={platform} device={device}>
          {`Next runs: ${nextRuns}`}
        </GroupedFooter>
      ) : mode === "cron" ? (
        <GroupedFooter platform={platform} device={device}>
          The server works out the next run when you save.
        </GroupedFooter>
      ) : null}
    </>
  );
}
