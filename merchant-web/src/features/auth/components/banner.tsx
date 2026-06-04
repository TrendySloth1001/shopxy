/**
 * Inline status banner — hairline border, soft fill, never chunky (CLAUDE.md
 * §9b). Used for form-level success and error feedback.
 */
export function Banner({
  variant,
  message,
}: {
  variant: "error" | "success";
  message: string;
}) {
  const styles =
    variant === "error"
      ? "border-error bg-error-soft text-error"
      : "border-brand bg-brand-soft text-brand-strong";
  return (
    <div
      role={variant === "error" ? "alert" : "status"}
      className={`flex items-start gap-sm rounded-md border px-md py-sm text-body-sm ${styles}`}
    >
      <span aria-hidden className="mt-px font-semibold">
        {variant === "error" ? "!" : "✓"}
      </span>
      <span>{message}</span>
    </div>
  );
}
