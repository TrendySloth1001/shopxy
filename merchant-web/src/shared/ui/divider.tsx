type DividerProps = {
  orientation?: "horizontal" | "vertical";
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
