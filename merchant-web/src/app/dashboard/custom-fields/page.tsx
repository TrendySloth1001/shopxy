"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Plus, Pencil, Trash2, Sparkles, Tag } from "@/shared/icons";
import { Divider } from "@/shared/ui/divider";
import {
  applyTemplate,
  createDefinition,
  createSection,
  deleteDefinition,
  deleteSection,
  getTree,
  listTemplates,
  updateDefinition,
  updateSection,
  type DefinitionInput,
} from "@/features/custom-fields/api";
import {
  CUSTOM_FIELD_TYPES,
  CUSTOM_FIELD_TYPE_LABEL_KEYS,
  type CustomFieldTree,
  type CustomFieldType,
  type Definition,
  type Section,
  type Template,
} from "@/features/custom-fields/schema";
import { CardsSkeleton } from "@/shared/ui/skeleton";
import { useCanManage } from "@/features/auth/use-can";
import { ComboSelect } from "@/shared/ui/combo-select";

type FieldEditor =
  | { mode: "create"; sectionId: string | null }
  | { mode: "edit"; field: Definition }
  | null;
type SectionEditor = { mode: "create" } | { mode: "edit"; section: Section } | null;

export default function CustomFieldsPage() {
  const t = useTranslations("customFields");
  const [tree, setTree] = useState<CustomFieldTree | null>(null);
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const [fieldEditor, setFieldEditor] = useState<FieldEditor>(null);
  const [sectionEditor, setSectionEditor] = useState<SectionEditor>(null);
  const canEdit = useCanManage("products");

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const [t, tpl] = await Promise.all([getTree(), listTemplates().catch(() => [])]);
        if (!active) return;
        setTree(t);
        setTemplates(tpl);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("errors.load"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  const sections = tree?.sections ?? [];

  async function onApplyTemplate(id: string) {
    setBusy(true);
    setActionError(null);
    try {
      await applyTemplate(id);
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.applyTemplate"));
    } finally {
      setBusy(false);
    }
  }

  async function onSaveField(input: DefinitionInput, editId?: string) {
    setBusy(true);
    setActionError(null);
    try {
      if (editId != null) await updateDefinition(editId, input);
      else await createDefinition(input);
      setFieldEditor(null);
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.saveField"));
    } finally {
      setBusy(false);
    }
  }

  async function onDeleteField(id: string) {
    setBusy(true);
    setActionError(null);
    try {
      await deleteDefinition(id);
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.deleteField"));
    } finally {
      setBusy(false);
    }
  }

  async function onSaveSection(name: string, editId?: string) {
    setBusy(true);
    setActionError(null);
    try {
      if (editId != null) await updateSection(editId, { name });
      else await createSection({ name });
      setSectionEditor(null);
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.saveSection"));
    } finally {
      setBusy(false);
    }
  }

  async function onDeleteSection(id: string) {
    setBusy(true);
    setActionError(null);
    try {
      await deleteSection(id);
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("errors.deleteSection"));
    } finally {
      setBusy(false);
    }
  }

  const isEmpty =
    !loading && sections.length === 0 && (tree?.ungrouped.length ?? 0) === 0;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">{t("list.title")}</h1>
          <p className="mt-xs text-body-md text-muted">
            {t("list.subtitle")}
          </p>
        </div>
        <div className="flex flex-wrap gap-sm">
          <button
            type="button"
            onClick={() => setSectionEditor({ mode: "create" })}
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> {t("actions.section")}
          </button>
          <button
            type="button"
            onClick={() => setFieldEditor({ mode: "create", sectionId: null })}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={18} /> {t("actions.newField")}
          </button>
        </div>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {actionError}
        </p>
      ) : null}

      {templates.length > 0 ? (
        <div className="mt-xl">
          <p className="text-label-md uppercase tracking-wide text-subtle">
            {t("templates.heading")}
          </p>
          <div className="mt-sm flex flex-wrap gap-sm">
            {templates.map((t) => (
              <button
                key={t.id}
                type="button"
                disabled={busy}
                onClick={() => onApplyTemplate(t.id)}
                title={t.description ?? undefined}
                className="inline-flex items-center gap-sm rounded-full border border-hairline px-md py-xs text-body-sm text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
              >
                <Sparkles size={14} className="text-brand" />
                {t.label}
                <span className="text-subtle">· {t.fieldCount}</span>
              </button>
            ))}
          </div>
        </div>
      ) : null}

      <Divider className="my-xl" />

      {loading ? (
        <CardsSkeleton count={3} />
      ) : error ? (
        <div className="flex flex-col items-start gap-md py-xxl">
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            {t("actions.tryAgain")}
          </button>
        </div>
      ) : isEmpty ? (
        <div className="flex flex-col items-center gap-sm py-massive text-center">
          <Tag size={28} className="text-subtle" />
          <p className="text-title-md text-ink">{t("empty.title")}</p>
          <p className="max-w-content text-body-md text-muted">
            {t("empty.body")}
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-xl">
          {sections.map((s) => (
            <FieldGroup
              key={s.id}
              title={s.name}
              fields={s.fields}
              onAddField={() => setFieldEditor({ mode: "create", sectionId: s.id })}
              onEditField={(f) => setFieldEditor({ mode: "edit", field: f })}
              onDeleteField={onDeleteField}
              onEditSection={() => setSectionEditor({ mode: "edit", section: s })}
              onDeleteSection={() => onDeleteSection(s.id)}
              canEdit={canEdit}
              busy={busy}
            />
          ))}
          {(tree?.ungrouped.length ?? 0) > 0 ? (
            <FieldGroup
              title={t("group.ungrouped")}
              fields={tree?.ungrouped ?? []}
              onAddField={() => setFieldEditor({ mode: "create", sectionId: null })}
              onEditField={(f) => setFieldEditor({ mode: "edit", field: f })}
              onDeleteField={onDeleteField}
              canEdit={canEdit}
              busy={busy}
            />
          ) : null}
        </div>
      )}

      {fieldEditor ? (
        <FieldEditorPanel
          editor={fieldEditor}
          sections={sections}
          busy={busy}
          onCancel={() => setFieldEditor(null)}
          onSave={onSaveField}
        />
      ) : null}

      {sectionEditor ? (
        <SectionEditorPanel
          editor={sectionEditor}
          busy={busy}
          onCancel={() => setSectionEditor(null)}
          onSave={onSaveSection}
        />
      ) : null}
    </div>
  );
}

function FieldGroup({
  title,
  fields,
  onAddField,
  onEditField,
  onDeleteField,
  onEditSection,
  onDeleteSection,
  canEdit,
  busy,
}: {
  title: string;
  fields: Definition[];
  onAddField: () => void;
  onEditField: (f: Definition) => void;
  onDeleteField: (id: string) => void;
  onEditSection?: () => void;
  onDeleteSection?: () => void;
  canEdit: boolean;
  busy: boolean;
}) {
  const t = useTranslations("customFields");
  const lockTitle = t("lockedHint");
  return (
    <section>
      <div className="flex items-center justify-between gap-md">
        <h2 className="text-title-md text-ink">{title}</h2>
        <div className="flex items-center gap-xs">
          <button
            type="button"
            onClick={onAddField}
            disabled={!canEdit}
            title={canEdit ? undefined : lockTitle}
            className="inline-flex h-8 items-center gap-xs rounded-button px-sm text-label-md text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
          >
            <Plus size={14} /> {t("actions.field")}
          </button>
          {onEditSection ? (
            <button
              type="button"
              onClick={onEditSection}
              disabled={!canEdit}
              aria-label={t("actions.renameSection")}
              title={canEdit ? undefined : lockTitle}
              className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
            >
              <Pencil size={14} />
            </button>
          ) : null}
          {onDeleteSection ? (
            <button
              type="button"
              onClick={onDeleteSection}
              disabled={busy || !canEdit}
              aria-label={t("actions.deleteSection")}
              title={canEdit ? undefined : lockTitle}
              className="rounded-md p-xs text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
            >
              <Trash2 size={14} />
            </button>
          ) : null}
        </div>
      </div>
      {fields.length === 0 ? (
        <p className="mt-sm text-body-sm text-subtle">{t("group.noFields")}</p>
      ) : (
        <ul className="mt-sm">
          {fields.map((f) => (
            <li
              key={f.id}
              className="flex items-center gap-md border-t border-hairline py-sm"
            >
              <div className="min-w-0 flex-1">
                <p className="truncate text-body-md text-ink">
                  {f.name}
                  {!f.isActive ? (
                    <span className="ml-sm rounded-full bg-surface-tint px-sm py-px text-body-sm text-muted">
                      {t("field.hiddenBadge")}
                    </span>
                  ) : null}
                </p>
                <p className="truncate text-body-sm text-muted">
                  {CUSTOM_FIELD_TYPE_LABEL_KEYS[f.type as CustomFieldType]
                    ? t(CUSTOM_FIELD_TYPE_LABEL_KEYS[f.type as CustomFieldType])
                    : f.type}
                  {f.unitSuffix ? ` · ${f.unitSuffix}` : ""}
                  {f.options.length > 0
                    ? ` · ${t("field.optionsCount", { count: f.options.length })}`
                    : ""}
                </p>
              </div>
              <button
                type="button"
                onClick={() => onEditField(f)}
                disabled={!canEdit}
                aria-label={t("actions.editField")}
                title={canEdit ? undefined : lockTitle}
                className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled disabled:hover:bg-transparent"
              >
                <Pencil size={16} />
              </button>
              <button
                type="button"
                onClick={() => onDeleteField(f.id)}
                disabled={busy || !canEdit}
                aria-label={t("actions.deleteField")}
                title={canEdit ? undefined : lockTitle}
                className="rounded-md p-xs text-muted transition-colors hover:bg-error-soft hover:text-error disabled:text-disabled disabled:hover:bg-transparent"
              >
                <Trash2 size={16} />
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function FieldEditorPanel({
  editor,
  sections,
  busy,
  onCancel,
  onSave,
}: {
  editor: NonNullable<FieldEditor>;
  sections: Section[];
  busy: boolean;
  onCancel: () => void;
  onSave: (input: DefinitionInput, editId?: string) => void;
}) {
  const t = useTranslations("customFields");
  const editing = editor.mode === "edit" ? editor.field : null;
  const [name, setName] = useState(editing?.name ?? "");
  const [type, setType] = useState<CustomFieldType>(
    (editing?.type as CustomFieldType) ?? "TEXT",
  );
  const [unitSuffix, setUnitSuffix] = useState(editing?.unitSuffix ?? "");
  const [optionsText, setOptionsText] = useState((editing?.options ?? []).join("\n"));
  const [sectionId, setSectionId] = useState<string>(
    editing?.sectionId != null
      ? String(editing.sectionId)
      : editor.mode === "create" && editor.sectionId != null
        ? String(editor.sectionId)
        : "",
  );

  function submit() {
    const trimmed = name.trim();
    if (!trimmed) return;
    const input: DefinitionInput = {
      name: trimmed,
      type,
      sectionId: sectionId ? sectionId : null,
    };
    if (type === "NUMBER" && unitSuffix.trim()) input.unitSuffix = unitSuffix.trim();
    if (type === "DROPDOWN") {
      input.options = optionsText
        .split("\n")
        .map((o) => o.trim())
        .filter(Boolean);
    }
    onSave(input, editing?.id);
  }

  return (
    <ModalShell
      title={editing ? t("fieldForm.editTitle") : t("fieldForm.newTitle")}
      onClose={onCancel}
    >
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("fieldForm.nameLabel")}</span>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          autoFocus
          placeholder={t("fieldForm.namePlaceholder")}
          className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>

      <ComboSelect
        label={t("fieldForm.typeLabel")}
        value={type}
        onChange={(v) => setType(v as CustomFieldType)}
        options={CUSTOM_FIELD_TYPES.map((ft) => ({
          value: ft,
          label: t(CUSTOM_FIELD_TYPE_LABEL_KEYS[ft]),
        }))}
        className="w-full"
      />

      {type === "NUMBER" ? (
        <label className="flex flex-col gap-xs">
          <span className="text-label-md text-muted">{t("fieldForm.unitSuffixLabel")}</span>
          <input
            value={unitSuffix}
            onChange={(e) => setUnitSuffix(e.target.value)}
            placeholder={t("fieldForm.unitSuffixPlaceholder")}
            className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
        </label>
      ) : null}

      {type === "DROPDOWN" ? (
        <label className="flex flex-col gap-xs">
          <span className="text-label-md text-muted">{t("fieldForm.optionsLabel")}</span>
          <textarea
            value={optionsText}
            onChange={(e) => setOptionsText(e.target.value)}
            rows={4}
            placeholder={t("fieldForm.optionsPlaceholder")}
            className="rounded-input border border-hairline bg-field px-md py-sm text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
          />
        </label>
      ) : null}

      <ComboSelect
        label={t("fieldForm.sectionLabel")}
        value={sectionId}
        onChange={setSectionId}
        options={[
          { value: "", label: t("group.ungrouped") },
          ...sections.map((s) => ({ value: String(s.id), label: s.name })),
        ]}
        className="w-full"
      />

      <ModalActions
        busy={busy}
        disabled={!name.trim()}
        confirmLabel={editing ? t("fieldForm.saveConfirm") : t("fieldForm.createConfirm")}
        onCancel={onCancel}
        onConfirm={submit}
      />
    </ModalShell>
  );
}

function SectionEditorPanel({
  editor,
  busy,
  onCancel,
  onSave,
}: {
  editor: NonNullable<SectionEditor>;
  busy: boolean;
  onCancel: () => void;
  onSave: (name: string, editId?: string) => void;
}) {
  const t = useTranslations("customFields");
  const editing = editor.mode === "edit" ? editor.section : null;
  const [name, setName] = useState(editing?.name ?? "");
  return (
    <ModalShell
      title={editing ? t("sectionForm.renameTitle") : t("sectionForm.newTitle")}
      onClose={onCancel}
    >
      <label className="flex flex-col gap-xs">
        <span className="text-label-md text-muted">{t("sectionForm.nameLabel")}</span>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          autoFocus
          placeholder={t("sectionForm.namePlaceholder")}
          className="h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
      </label>
      <ModalActions
        busy={busy}
        disabled={!name.trim()}
        confirmLabel={editing ? t("sectionForm.saveConfirm") : t("sectionForm.createConfirm")}
        onCancel={onCancel}
        onConfirm={() => name.trim() && onSave(name.trim(), editing?.id)}
      />
    </ModalShell>
  );
}

function ModalShell({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-scrim/30 p-lg sm:items-center"
      onClick={onClose}
    >
      <div
        className="flex w-full max-w-form flex-col gap-md rounded-dialog bg-surface p-lg shadow-menu"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-title-md text-ink">{title}</h3>
        {children}
      </div>
    </div>
  );
}

function ModalActions({
  busy,
  disabled,
  confirmLabel,
  onCancel,
  onConfirm,
}: {
  busy: boolean;
  disabled?: boolean;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const t = useTranslations("customFields");
  return (
    <div className="mt-sm flex justify-end gap-md">
      <button
        type="button"
        onClick={onCancel}
        disabled={busy}
        className="inline-flex h-10 items-center rounded-button px-md text-label-md text-muted transition-colors hover:text-ink disabled:text-disabled"
      >
        {t("actions.cancel")}
      </button>
      <button
        type="button"
        onClick={onConfirm}
        disabled={busy || disabled}
        className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
      >
        {busy ? t("actions.saving") : confirmLabel}
      </button>
    </div>
  );
}
