import { GroupedDialog, type GroupedDialogProps } from "../GroupedDialog/GroupedDialog";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedChoiceRow } from "../GroupedChoiceRow/GroupedChoiceRow";

export interface KanbanTaskChoiceDialogProps extends Omit<GroupedDialogProps, "children"> {
  /** Assignee names including Nobody, or the priority labels Normal, P1, P2, P3. */
  options: string[];
  /** Index of the current value. */
  selected: number;
  /** Pick a value and close the dialog; Done or dismissal leaves it unchanged. */
  onPick?: (index: number) => void;
}

export function KanbanTaskChoiceDialog({ options, selected, onPick, ...dialog }: KanbanTaskChoiceDialogProps) {
  return <GroupedDialog {...dialog}>
    <GroupedSection dividerIndent="choice">
      {options.map((option, index) => <GroupedChoiceRow key={index} title={option} wrapTitle
        checked={index === selected} disabled={!onPick} onSelect={() => onPick?.(index)} />)}
    </GroupedSection>
  </GroupedDialog>;
}
