/**
 * Rotating soft background tints for letter-monogram fallbacks — category
 * tiles, home pucks, and category headers all cycle through the same set.
 * Single source so those three surfaces can't drift apart.
 */
export const CATEGORY_TINTS = [
  "#E3E8F4",
  "#F3E4D6",
  "#F9E1EA",
  "#E6F2EC",
  "#EFE9DD",
  "#E0E1E6",
  "#E7DFD4",
  "#E4DECF",
  "#E6F2DA",
  "#DEEAF1",
] as const;
