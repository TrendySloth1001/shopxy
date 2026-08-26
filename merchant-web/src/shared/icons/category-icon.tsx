import { createElement } from "react";
import { resolveCategoryIcon } from "./category-icons";

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
