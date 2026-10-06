import { Chip } from "../Chip/Chip";
import "./ScheduleFilterBar.css";

/** Which jobs the Schedules list shows beside the profile choice. */
export type ScheduleFilter = "all" | "failing" | "paused";

export interface ScheduleFilterBarProps {
  /** The active profile, offered as "work (active)". Omitted: only "All profiles" is shown, selected. */
  activeProfile?: string;
  /** List the jobs of every profile (each row then shows its profile chip). */
  allProfiles?: boolean;
  /** `failing` or `paused` narrows the list; `all` shows every job. */
  filter?: ScheduleFilter;
  /** Jobs whose last run failed, shown as "Failing (2)"; hidden at 0. */
  failingCount?: number;
  /** Offer the profile chips (default true). Off in a Mac window, whose toolbar picks the scope ("This profile" / "All profiles"). */
  showScope?: boolean;
  /** A profile chip was pressed: `true` for "All profiles". */
  onAllProfilesChange?: (all: boolean) => void;
  /** Failing or Paused was toggled; `all` when the selected one was pressed again. */
  onFilterChange?: (filter: ScheduleFilter) => void;
}

/**
 * The chips above the Schedules list: the active profile or all profiles
 * (a choice), and the Failing and Paused filters. They wrap onto a second
 * line rather than scroll. Same on every platform, as in the app.
 */
export function ScheduleFilterBar({
  activeProfile,
  allProfiles = false,
  filter = "all",
  failingCount = 0,
  showScope = true,
  onAllProfilesChange,
  onFilterChange,
}: ScheduleFilterBarProps) {
  const toggle = (f: ScheduleFilter) =>
    onFilterChange?.(filter === f ? "all" : f);
  return (
    <div className="h-schedule-filter-bar">
      {showScope && activeProfile ? (
        <Chip
          label={`${activeProfile} (active)`}
          selected={!allProfiles}
          onClick={() => onAllProfilesChange?.(false)}
        />
      ) : null}
      {showScope ? (
        <Chip
          label="All profiles"
          selected={allProfiles || !activeProfile}
          onClick={() => onAllProfilesChange?.(true)}
        />
      ) : null}
      <Chip
        label={failingCount > 0 ? `Failing (${failingCount})` : "Failing"}
        selected={filter === "failing"}
        onClick={() => toggle("failing")}
      />
      <Chip
        label="Paused"
        selected={filter === "paused"}
        onClick={() => toggle("paused")}
      />
    </div>
  );
}
