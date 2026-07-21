import { createElement } from "react";
import { resolveCategoryIcon } from "./category-icons";

/**
 * Renders the lucide icon for a stored category `iconName`. Using
 * `createElement` (rather than assigning the resolved icon to a capitalised
 * local and rendering it) keeps the `react-hooks/static-components` rule happy.
 */
export function CategoryIcon({
  name,
  size = 24,
  className,
}: {
  name?: string | null;
  size?: number;
  className?: string;
}) {
  return createElement(resolveCategoryIcon(name), { size, className });
}
