import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { SelectField } from "../SelectField/SelectField";
import { TextField } from "../TextField/TextField";
import "./SchedulePicker.css";

/** How a job's schedule is entered. */
export type ScheduleMode = "every" | "daily" | "weekly" | "once" | "cron";

/** A unit of an `every` schedule. */
export type ScheduleEveryUnit = "minutes" | "hours" | "days";

const modes: [ScheduleMode, string][] = [
  ["every", "Every"],
  ["daily", "Daily"],
  ["weekly", "Weekly"],
  ["once", "Once"],
  ["cron", "Cron"],
];

const week = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export interface SchedulePickerProps {
  /** The mode chip picked; it decides the inputs under the chips. */
  mode: ScheduleMode;
  /** `every`: the number typed, e.g. `30`. */
  amount?: string;
  /** `every`: the unit picked. */
  unit?: ScheduleEveryUnit;
  /** `daily`, `weekly`, `once`: the time, `08:00`. */
  time?: string;
  /** `weekly`: the days picked, as `Mon` … `Sun`. */
  days?: string[];
  /** `once`: the date, already formatted: "Sep 18, 2026". */
  date?: string;
  /** `cron`: the expression or phrase typed. */
  cron?: string;
  /** The next runs worked out from a valid schedule: "tomorrow 08:00, Thu 08:00, Fri 08:00". Without it a `cron` schedule says the server works it out on save. */
  nextRuns?: string;
  /** A mode chip pressed. */
  onModeChange?: (mode: ScheduleMode) => void;
  /** `every`: the amount typed. */
  onAmountChange?: (amount: string) => void;
  /** `every`: a unit picked. */
  onUnitChange?: (unit: ScheduleEveryUnit) => void;
  /** `weekly`: a day toggled. */
  onDayToggle?: (day: string) => void;
  /** The time button pressed (the app opens its time picker). */
  onPickTime?: () => void;
  /** `once`: the date button pressed (the app opens its date picker). */
  onPickDate?: () => void;
  /** `cron`: the expression typed. */
  onCronChange?: (cron: string) => void;
}

/**
 * The "When" of the job form: Every, Daily, Weekly, Once and Cron chips,
 * then the inputs of the mode picked (a number and unit, a time button, day
 * chips, a date button, or a cron field) and the next runs in muted text.
 * Put it in a `FormSection` titled "When". Same on every platform, as in the
 * app; the pickers its buttons open are the platform's.
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
  onModeChange,
  onAmountChange,
  onUnitChange,
  onDayToggle,
  onPickTime,
  onPickDate,
  onCronChange,
}: SchedulePickerProps) {
  const timeButton = (
    <div>
      <Button variant="outlined" icon="schedule" onClick={onPickTime}>
        {time}
      </Button>
    </div>
  );
  return (
    <div className="h-schedule-picker">
      <div className="h-schedule-picker__chips">
        {modes.map(([m, label]) => (
          <Chip
            key={m}
            label={label}
            selected={m === mode}
            onClick={() => onModeChange?.(m)}
          />
        ))}
      </div>
      {mode === "every" ? (
        <div className="h-schedule-picker__every">
          <TextField
            className="h-schedule-picker__amount"
            label="Every"
            inputMode="numeric"
            value={amount}
            onChange={(e) => onAmountChange?.(e.target.value)}
            readOnly={!onAmountChange}
          />
          <div className="h-schedule-picker__unit">
            <SelectField
              value={unit}
              options={["minutes", "hours", "days"]}
              onChange={(v) => onUnitChange?.(v as ScheduleEveryUnit)}
            />
          </div>
        </div>
      ) : mode === "daily" ? (
        timeButton
      ) : mode === "weekly" ? (
        <>
          <div className="h-schedule-picker__days">
            {week.map((d) => (
              <Chip
                key={d}
                label={d}
                selected={days.includes(d)}
                onClick={() => onDayToggle?.(d)}
              />
            ))}
          </div>
          {timeButton}
        </>
      ) : mode === "once" ? (
        <div className="h-schedule-picker__chips">
          <Button variant="outlined" icon="calendar_today" onClick={onPickDate}>
            {date ?? "Choose a date"}
          </Button>
          <Button variant="outlined" icon="schedule" onClick={onPickTime}>
            {time}
          </Button>
        </div>
      ) : (
        <TextField
          label="Schedule"
          mono
          value={cron}
          helper="A five-field cron expression, for example 0 9 * * 1-5, or a phrase like every monday 9am"
          onChange={(e) => onCronChange?.(e.target.value)}
          readOnly={!onCronChange}
        />
      )}
      {nextRuns ? (
        <div className="h-schedule-picker__note">{`Next runs: ${nextRuns}`}</div>
      ) : mode === "cron" ? (
        <div className="h-schedule-picker__note">
          The server works out the next run when you save.
        </div>
      ) : null}
    </div>
  );
}
