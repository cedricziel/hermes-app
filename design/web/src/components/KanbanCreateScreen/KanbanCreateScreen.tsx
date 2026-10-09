import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedMenuRow } from "../GroupedMenuRow/GroupedMenuRow";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedSegmentedRow } from "../GroupedSegmentedRow/GroupedSegmentedRow";
import { GroupedTextFieldRow } from "../GroupedTextFieldRow/GroupedTextFieldRow";
import { GroupedValueRow } from "../GroupedValueRow/GroupedValueRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import type { AppleDevice, Platform } from "../../platform";

export interface KanbanCreateScreenProps {
  /** Title typed so far; Create and "Estimate the work" need one. */
  title?: string;
  /** Description typed so far. */
  description?: string;
  /** The board the task goes on, the bar's subtitle: "default". */
  board?: string;
  /** Profiles the task can be assigned to, offered after "Auto (triage picks)". */
  assignees?: string[];
  /** The assignee picked; omitted means "Auto (triage picks)". */
  assignee?: string;
  /**
   * The Assignment group's Model row. `list`: a value row opening the
   * picker with the plugin's models ("claude-opus-4 · High", or "Profile
   * default" when none is picked). `freeText`: the plugin lists no models,
   * so a "Model" text field row (`modelName`) and the footer "Leave the
   * model empty for the profile default." `loading`: no row yet.
   */
  modelField?: "list" | "freeText" | "loading";
  /** `list`: the model picked; omitted shows "Profile default". */
  model?: string;
  /** `list`: the reasoning effort picked with it, e.g. `High`. */
  effort?: string;
  /** `freeText`: the model name typed. */
  modelName?: string;
  /** 0 is Normal, 1 to 3 are P1 to P3. */
  priority?: number;
  /** Start in Triage (default) rather than Todo. */
  triage?: boolean;
  /** The estimate's summary, the subtitle of "Estimate the work": "About 2 hours of work". */
  estimate?: string;
  /** The estimate is being worked out: a spinner at the end of "Estimate the work", which ignores clicks. */
  estimating?: boolean;
  /** The task is being created: a spinner in Create's place. */
  saving?: boolean;
  /** Which menu starts open, for previews. */
  defaultOpen?: "assignee";
  /**
   * A grouped form on a `SettingsScaffold`, Create last in the bar.
   * `apple` + `touch` (iPhone): Cancel leading, "Create" as a semibold text
   * button; Title and Description borderless in one group, Assignee and
   * Model as value rows with chevrons under "ASSIGNMENT", Priority and
   * Start as sliding segmented controls. `apple` + `mac`: back button, a
   * small filled Create, 13px rows with pop-up buttons in a centred 600px
   * column. `material`: a close X, floating-label fields, label-over-value
   * rows and pill segmented controls. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`. Defaults to the enclosing `AppShell`'s, else `touch`. */
  device?: AppleDevice;
  /** The title was edited. */
  onTitleChange?: (title: string) => void;
  /** The description was edited. */
  onDescriptionChange?: (description: string) => void;
  /** An assignee was picked; `undefined` for "Auto (triage picks)". */
  onAssigneeChange?: (assignee: string | undefined) => void;
  /** The Model row was pressed (the app opens the model picker with a "Use the profile's default" entry). */
  onPickModel?: () => void;
  /** The free-text model name was edited. */
  onModelNameChange?: (name: string) => void;
  /** A priority was picked. */
  onPriorityChange?: (priority: number) => void;
  /** Triage or Todo was picked. */
  onTriageChange?: (triage: boolean) => void;
  /** "Estimate the work" pressed. */
  onEstimate?: () => void;
  /** Create pressed. */
  onCreate?: () => void;
  /** Cancel, close or back pressed (the app asks before throwing a typed task away). */
  onBack?: () => void;
}

const auto = "Auto (triage picks)";

/**
 * "New task" on the Kanban board, a grouped form: Title and Description,
 * "Estimate the work" (greyed out until there is a title), the Assignment
 * group (Assignee menu, Model), Priority (Normal, P1 to P3) and Start as
 * (Triage, Todo), with Create in the bar and the board as the subtitle.
 * Fills its parent.
 */
export function KanbanCreateScreen({
  title = "",
  description = "",
  board,
  assignees = [],
  assignee,
  modelField = "list",
  model,
  effort,
  modelName = "",
  priority = 0,
  triage = true,
  estimate,
  estimating = false,
  saving = false,
  defaultOpen,
  platform,
  device,
  onTitleChange,
  onDescriptionChange,
  onAssigneeChange,
  onPickModel,
  onModelNameChange,
  onPriorityChange,
  onTriageChange,
  onEstimate,
  onCreate,
  onBack,
}: KanbanCreateScreenProps) {
  const back = onBack ?? (() => {});
  const hasTitle = title.trim() !== "";
  const options =
    assignee && !assignees.includes(assignee)
      ? [assignee, ...assignees]
      : assignees;
  return (
    <SettingsScaffold
      title="New task"
      subtitle={board}
      onBack={back}
      onCancel={back}
      formAction={{ label: "Create", busy: saving, onClick: onCreate }}
      platform={platform}
      device={device}
    >
      <GroupedListView>
        <GroupedSection>
          <GroupedTextFieldRow
            label="Title"
            value={title}
            onChange={onTitleChange}
          />
          <GroupedTextFieldRow
            label="Description"
            rows={3}
            value={description}
            onChange={onDescriptionChange}
          />
        </GroupedSection>
        <GroupedSection>
          <GroupedRow
            icon="speed"
            title="Estimate the work"
            subtitle={estimate}
            trailing={
              estimating ? <Spinner size={18} label="Estimating" /> : undefined
            }
            chevron={false}
            disabled={!hasTitle}
            onClick={hasTitle && !estimating ? onEstimate : undefined}
          />
        </GroupedSection>
        <GroupedSection
          header="Assignment"
          footer={
            modelField === "freeText"
              ? "Leave the model empty for the profile default."
              : undefined
          }
        >
          <GroupedMenuRow
            title="Assignee"
            options={[auto, ...options]}
            selected={assignee ? options.indexOf(assignee) + 1 : 0}
            open={defaultOpen === "assignee"}
            onSelect={(i) =>
              onAssigneeChange?.(i === 0 ? undefined : options[i - 1])
            }
          />
          {modelField === "list" ? (
            <GroupedValueRow
              title="Model"
              value={
                model
                  ? [model, effort].filter(Boolean).join(" · ")
                  : "Profile default"
              }
              onClick={onPickModel ?? (() => {})}
            />
          ) : modelField === "freeText" ? (
            <GroupedTextFieldRow
              label="Model"
              value={modelName}
              onChange={onModelNameChange}
            />
          ) : null}
        </GroupedSection>
        <GroupedSection header="Priority">
          <GroupedSegmentedRow
            label="Priority"
            labels={["Normal", "P1", "P2", "P3"]}
            value={priority}
            onChange={onPriorityChange}
          />
        </GroupedSection>
        <GroupedSection header="Start as">
          <GroupedSegmentedRow
            label="Start as"
            labels={["Triage", "Todo"]}
            value={triage ? 0 : 1}
            onChange={(i) => onTriageChange?.(i === 0)}
          />
        </GroupedSection>
      </GroupedListView>
    </SettingsScaffold>
  );
}
