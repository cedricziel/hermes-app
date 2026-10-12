import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import type { AppleDevice, Platform } from "../../platform";

export interface ChatSuggestionsProps {
  items: { title: string; description: string }[];
  onChoose?: (index: number) => void;
  header?: string;
  selectedIndex?: number;
  maxHeight?: number;
  platform?: Platform;
  device?: AppleDevice;
}

export function ChatSuggestions({
  items, onChoose, header, selectedIndex, maxHeight = 280, platform, device,
}: ChatSuggestionsProps) {
  if (items.length === 0) return null;
  return (
    <div style={{ maxHeight, overflowY: "auto", marginInline: 8 }}>
      <GroupedSection header={header} platform={platform} device={device}>
        {items.map((item, index) => (
          <GroupedRow key={`${index}:${item.title}`} title={item.title}
            subtitle={item.description} selected={selectedIndex === index}
            chevron={false} disabled={!onChoose}
            onClick={onChoose ? () => onChoose(index) : undefined} />
        ))}
      </GroupedSection>
    </div>
  );
}
