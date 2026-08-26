import { z } from "zod";

export const CUSTOM_FIELD_TYPES = [
  "TEXT",
  "LONG_TEXT",
  "NUMBER",
  "DATE",
  "BOOLEAN",
  "DROPDOWN",
] as const;
export type CustomFieldType = (typeof CUSTOM_FIELD_TYPES)[number];

export const CUSTOM_FIELD_TYPE_LABEL_KEYS: Record<CustomFieldType, string> = {
  TEXT: "types.text",
  LONG_TEXT: "types.longText",
  NUMBER: "types.number",
  DATE: "types.date",
  BOOLEAN: "types.boolean",
  DROPDOWN: "types.dropdown",
};

const arr = <T extends z.ZodTypeAny>(s: T) =>
  z
    .array(s)
    .nullish()
    .transform((v) => v ?? []);

export const definitionSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    type: z.string(),
    options: arr(z.string()),
    unitSuffix: z.string().nullish(),
    icon: z.string().nullish(),
    sectionId: z.coerce.string().nullish(),
    sortOrder: z.coerce.number().default(0),
    isActive: z.boolean().default(true),
  })
  .passthrough();
export type Definition = z.infer<typeof definitionSchema>;

export const sectionSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    icon: z.string().nullish(),
    sortOrder: z.coerce.number().default(0),
    isActive: z.boolean().default(true),
  })
  .passthrough();
export type Section = z.infer<typeof sectionSchema>;

export const treeSectionSchema = sectionSchema.extend({
  fields: arr(definitionSchema),
});
export type TreeSection = z.infer<typeof treeSectionSchema>;

export const treeSchema = z.object({
  sections: z.array(treeSectionSchema).nullish().transform((v) => v ?? []),
  ungrouped: arr(definitionSchema),
});
export type CustomFieldTree = z.infer<typeof treeSchema>;

export const templateSchema = z
  .object({
    id: z.string(),
    label: z.string(),
    icon: z.string().nullish(),
    description: z.string().nullish(),
    fieldCount: z.coerce.number().default(0),
  })
  .passthrough();
export type Template = z.infer<typeof templateSchema>;
