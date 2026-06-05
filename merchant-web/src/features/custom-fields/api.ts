import {
  treeSchema,
  templateSchema,
  definitionSchema,
  type CustomFieldTree,
  type Definition,
  type Template,
} from "./schema";
import { z } from "zod";

async function okJson<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

async function okVoid(res: Response, fallback: string): Promise<void> {
  if (!res.ok && res.status !== 204) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
}

export function getTree(): Promise<CustomFieldTree> {
  return fetch("/api/custom-fields/tree?active=false", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => treeSchema.parse(raw), "Could not load custom fields."),
  );
}

export function listTemplates(): Promise<Template[]> {
  return fetch("/api/custom-fields/templates", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => z.array(templateSchema).parse(raw), "Could not load templates."),
  );
}

export function applyTemplate(templateId: string): Promise<void> {
  return fetch("/api/custom-fields/templates/apply", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ templateId }),
  }).then((r) => okVoid(r, "Could not apply the template."));
}

export type DefinitionInput = {
  name: string;
  type: string;
  options?: string[];
  unitSuffix?: string;
  icon?: string;
  sectionId?: number | null;
};

export function createDefinition(input: DefinitionInput): Promise<Definition> {
  return fetch("/api/custom-fields", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okJson(r, (raw) => definitionSchema.parse(raw), "Could not create the field."));
}

export function updateDefinition(
  id: number,
  input: Partial<DefinitionInput> & { isActive?: boolean },
): Promise<Definition> {
  return fetch(`/api/custom-fields/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okJson(r, (raw) => definitionSchema.parse(raw), "Could not save the field."));
}

export function deleteDefinition(id: number): Promise<void> {
  return fetch(`/api/custom-fields/${id}`, { method: "DELETE" }).then((r) =>
    okVoid(r, "Could not delete the field."),
  );
}

export type SectionInput = { name: string; icon?: string };

export function createSection(input: SectionInput): Promise<void> {
  return fetch("/api/custom-fields/sections", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okVoid(r, "Could not create the section."));
}

export function updateSection(
  id: number,
  input: Partial<SectionInput> & { isActive?: boolean },
): Promise<void> {
  return fetch(`/api/custom-fields/sections/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okVoid(r, "Could not save the section."));
}

export function deleteSection(id: number): Promise<void> {
  return fetch(`/api/custom-fields/sections/${id}`, { method: "DELETE" }).then((r) =>
    okVoid(r, "Could not delete the section."),
  );
}
