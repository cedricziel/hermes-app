import { useEffect, useRef, type KeyboardEvent } from "react";

const focusable =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Focus handling of a modal panel (`Sheet`, `AlertDialog`): on mount the
 * panel takes focus, Escape calls `onDismiss`, Tab stays inside the panel,
 * and focus goes back where it was when the panel goes away. Give the
 * returned `ref` and `onKeyDown` to the panel, with `tabIndex={-1}`.
 */
export function useModalFocus<T extends HTMLElement>(onDismiss?: () => void) {
  const panel = useRef<T>(null);
  const dismiss = useRef(onDismiss);
  dismiss.current = onDismiss;

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    panel.current?.focus({ preventScroll: true });
    const onKey = (e: globalThis.KeyboardEvent) => {
      if (e.key === "Escape" && dismiss.current) {
        e.stopPropagation();
        dismiss.current();
      }
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      previous?.focus?.({ preventScroll: true });
    };
  }, []);

  const onKeyDown = (e: KeyboardEvent<T>) => {
    if (e.key !== "Tab" || !panel.current) return;
    const items = Array.from(
      panel.current.querySelectorAll<HTMLElement>(focusable),
    );
    if (items.length === 0) {
      e.preventDefault();
      return;
    }
    const first = items[0];
    const last = items[items.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  };

  return { ref: panel, onKeyDown };
}
