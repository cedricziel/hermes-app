import { GroupedRow } from "./GroupedRow";
import { IconButton } from "../IconButton/IconButton";
import { Menu, MenuAnchor, useMenuState, type MenuItem } from "../Menu/Menu";
import { useGroupedChrome } from "../../platform";

/** A grouped row that opens on click and offers `actions` in a trailing "…" menu, as the trailing menu of the app's `_MenuRow` in `kanban_list_rows.dart` (its iOS swipe, long press and Mac right-click are not drawn). */
export function GroupedMenuButtonRow<T extends string>({
  title,
  subtitle,
  caption,
  value,
  actions,
  menuLabel,
  menuOpen = false,
  onClick,
  onAction,
}: {
  title: string;
  subtitle: string;
  caption?: string;
  value?: string;
  actions: MenuItem<T>[];
  menuLabel: string;
  menuOpen?: boolean;
  onClick?: () => void;
  onAction?: (action: T) => void;
}) {
  const chrome = useGroupedChrome();
  const [open, setOpen] = useMenuState(menuOpen);
  return (
    <GroupedRow
      title={title}
      subtitle={subtitle}
      caption={caption}
      value={value}
      onClick={onClick}
      trailing={
        <MenuAnchor>
          <IconButton
            icon="more_vert"
            label={`${menuLabel} actions`}
            size={chrome === "mac" ? 32 : 40}
            aria-haspopup="menu"
            aria-expanded={open}
            onMouseDown={(e) => e.stopPropagation()}
            onClick={() => setOpen((o) => !o)}
          />
          {open ? (
            <Menu<T>
              align="end"
              label={menuLabel}
              device={chrome === "ios" ? "touch" : "mac"}
              items={actions}
              onSelect={(item) => {
                setOpen(false);
                if (item.value) onAction?.(item.value);
              }}
            />
          ) : null}
        </MenuAnchor>
      }
    />
  );
}
