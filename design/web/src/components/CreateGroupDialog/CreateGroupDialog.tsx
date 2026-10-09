import { useEffect, useState } from "react";
import { Button } from "../Button/Button";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import {
  GroupedFooter,
  GroupedSection,
} from "../GroupedSection/GroupedSection";
import { Icon } from "../Icon/Icon";
import { SettingsSearchField } from "../SettingsSearchField/SettingsSearchField";
import { Sheet } from "../Sheet/Sheet";
import { TextField } from "../TextField/TextField";
import {
  cx,
  DeviceScope,
  useGroupedChrome,
  type AppleDevice,
} from "../../platform";
import "../GroupedChoiceRow/GroupedChoiceRow.css";
import "./CreateGroupDialog.css";

/** A bot that can join a group. */
export interface GroupMemberOption {
  /** The bot's profile name, used as its id and handle: "writer". */
  name: string;
  /** Its title: "Editor". */
  title: string;
}

/** What a member of a hosted group cannot do (the app's `groupInteractionLimitation`). */
export const groupInteractionLimitation =
  "Interactive requests cannot be answered in hosted groups. A member may wait for a response; use Stop if the task stalls.";

export interface CreateGroupDialogProps {
  /** Every bot on the roster, in order. */
  members: GroupMemberOption[];
  /** The room name typed so far. Create stays disabled while it is empty. */
  name?: string;
  /** Names of the picked bots. Create needs 2 to 6; with 6 picked the other rows are dimmed. */
  selected?: string[];
  /** The member search text, matched against title and name. */
  query?: string;
  /** The room is being created: the fields are disabled and the button reads "Creating…". */
  pending?: boolean;
  /** The create failed: the message shows under the list, the button reads "Retry", and the name and members stay locked (Retry resends the same request). */
  error?: string;
  onNameChange?: (name: string) => void;
  onSelectedChange?: (selected: string[]) => void;
  onQueryChange?: (query: string) => void;
  onCancel?: () => void;
  onCreate?: () => void;
  /**
   * Accepted from the screen but does not change the look: the app shows
   * this Material dialog on every platform, so on a Mac the title, field,
   * search, member rows and buttons all keep their phone size.
   */
  device?: AppleDevice;
}

/**
 * Create group, from the Bots screen's Groups section: the Material dialog
 * the app shows on every platform (28px corners, "Create group", Cancel and
 * a filled Create), the same size on a Mac. Inside: "Room name", a "Search
 * members" field, then the bots as one inset group whose
 * rows are "Editor" over "@writer", with a blue check at the trailing edge
 * on Apple and a checkbox at the leading edge on Material. The footer says
 * "Choose 2–6 bots. Membership is fixed for this room." and that hosted
 * groups cannot answer interactive requests. Like the app's, it does not
 * close on a click outside or Escape. It covers its nearest positioned
 * ancestor; put it inside the screen.
 */
export function CreateGroupDialog({
  members,
  name: nameProp = "",
  selected: selectedProp = [],
  query: queryProp = "",
  pending = false,
  error,
  onNameChange,
  onSelectedChange,
  onQueryChange,
  onCancel,
  onCreate,
}: CreateGroupDialogProps) {
  const chrome = useGroupedChrome(undefined, "touch");
  const apple = chrome !== "material";
  const [name, setName] = useState(nameProp);
  const [selected, setSelected] = useState(selectedProp);
  const [query, setQuery] = useState(queryProp);
  useEffect(() => setName(nameProp), [nameProp]);
  useEffect(() => setSelected(selectedProp), [selectedProp.join("\n")]);
  useEffect(() => setQuery(queryProp), [queryProp]);

  const locked = pending || error !== undefined;
  const q = query.trim().toLowerCase();
  const shown = members.filter((m) =>
    `${m.title} ${m.name}`.toLowerCase().includes(q),
  );
  const toggle = (id: string) => {
    const next = selected.includes(id)
      ? selected.filter((s) => s !== id)
      : [...selected, id];
    setSelected(next);
    onSelectedChange?.(next);
  };
  const canCreate =
    !pending &&
    name.trim() !== "" &&
    selected.length >= 2 &&
    selected.length <= 6;

  return (
    <DeviceScope device="touch">
      <Sheet
        presentation="dialog"
        title="Create group"
        width={528}
        actions={
          <>
            <Button variant="text" disabled={pending} onClick={onCancel}>
              Cancel
            </Button>
            <Button disabled={!canCreate} onClick={onCreate}>
              {pending ? "Creating…" : error ? "Retry" : "Create"}
            </Button>
          </>
        }
      >
        <div className="h-create-group">
          <TextField
            label="Room name"
            value={name}
            disabled={locked}
            onChange={(e) => {
              setName(e.target.value);
              onNameChange?.(e.target.value);
            }}
          />
          <SettingsSearchField
            query={query}
            hint="Search members"
            onChange={(v) => {
              setQuery(v);
              onQueryChange?.(v);
            }}
          />
          <div className="h-create-group__members">
            <GroupedSection
              dividerIndent={apple ? undefined : "leading"}
              footer="Choose 2–6 bots. Membership is fixed for this room."
              label="Members"
            >
              {shown.map((m) => {
                const checked = selected.includes(m.name);
                const enabled = !locked && (checked || selected.length < 6);
                const mark = apple ? (
                  <span className="h-choice-check" aria-hidden="true">
                    {checked ? (
                      <Icon name="check" apple="checkmark" size={17} />
                    ) : null}
                  </span>
                ) : (
                  <span
                    className={cx(
                      "h-create-group__box",
                      checked && "h-create-group__box--on",
                    )}
                    aria-hidden="true"
                  >
                    {checked ? <Icon name="check" size={14} /> : null}
                  </span>
                );
                return (
                  <GroupedRow
                    key={m.name}
                    title={m.title}
                    subtitle={`@${m.name}`}
                    leading={apple ? undefined : mark}
                    trailing={apple ? mark : undefined}
                    chevron={false}
                    disabled={!enabled}
                    checkboxChecked={checked}
                    onClick={() => toggle(m.name)}
                  />
                );
              })}
              {shown.length === 0 ? (
                <GroupedRow title="No matching bots" />
              ) : null}
            </GroupedSection>
            <GroupedFooter>{groupInteractionLimitation}</GroupedFooter>
            {error ? <GroupedFooter error>{error}</GroupedFooter> : null}
          </div>
        </div>
      </Sheet>
    </DeviceScope>
  );
}
