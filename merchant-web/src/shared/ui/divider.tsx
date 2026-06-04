/**
 * Divider — the house primitive for separating content.
 *
 * Per CLAUDE.md §9b we group content with hairline dividers and whitespace,
 * NOT with bordered/elevated boxes. Reach for this before reaching for a card.
 */

type DividerProps = {
  /** Vertical divider for inline/row separation. Defaults to horizontal. */
  orientation?: "horizontal" | "vertical";
  /** Inset the divider so it doesn't touch the container edge. */
  inset?: boolean;
  className?: string;
};

export function Divider({
  orientation = "horizontal",
  inset = false,
  className = "",
}: DividerProps) {
  if (orientation === "vertical") {
    return (
      <span
        role="separator"
        aria-orientation="vertical"
        className={`inline-block w-px self-stretch bg-hairline ${inset ? "my-sm" : ""} ${className}`}
      />
    );
  }
  return (
    <hr
      className={`h-px border-0 bg-hairline ${inset ? "mx-lg" : ""} ${className}`}
    />
  );
}
