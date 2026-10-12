import { useLayoutEffect, useRef } from "react";
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
  const panelRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const panel = panelRef.current;
    const selected = selectedRef.current;
    if (!panel || !selected) return;
    const viewport = panel.getBoundingClientRect();
    const row = selected.getBoundingClientRect();
    if (row.bottom > viewport.bottom) panel.scrollTop += row.bottom - viewport.bottom;
    if (row.top < viewport.top) panel.scrollTop += row.top - viewport.top;
  }, [selectedIndex, items, maxHeight, platform, device]);
  if (items.length === 0) return null;
  return (
    <div ref={panelRef} style={{ maxHeight, overflowY: "auto", marginInline: 8 }}>
      <GroupedSection header={header} platform={platform} device={device}>
        {items.map((item, index) => (
          <div key={`${index}:${item.title}`} ref={selectedIndex === index ? selectedRef : undefined}>
          <GroupedRow title={item.title}
            subtitle={item.description} selected={selectedIndex === index}
            chevron={false} disabled={!onChoose}
            onClick={onChoose ? () => onChoose(index) : undefined} />
          </div>
        ))}
      </GroupedSection>
    </div>
  );
}
