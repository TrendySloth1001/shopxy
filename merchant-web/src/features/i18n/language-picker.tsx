"use client";

import { useLocale } from "next-intl";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { Check } from "@/shared/icons";
import { setLocale } from "./actions";

/** Languages offered by the picker. Names are endonyms (each in its own script)
 *  — the convention for language pickers, so they read the same in every locale. */
const LANGUAGES = [
  { code: "en", label: "English" },
  { code: "hi", label: "हिन्दी" },
] as const;

/**
 * UI-language picker for Settings → Preferences. A server action writes the
 * `locale` cookie (read by src/i18n/request.ts); the route then refreshes so the
 * whole app re-renders with the new messages, `<html lang>` and Devanagari font.
 * Mirrors the ThemePicker chip pattern.
 */
export function LanguagePicker() {
  const locale = useLocale();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function choose(code: string) {
    if (code === locale) return;
    startTransition(async () => {
      await setLocale(code);
      router.refresh();
    });
  }

  return (
    <div role="radiogroup" aria-label="App language" className="flex flex-wrap gap-sm">
      {LANGUAGES.map((lang) => {
        const selected = lang.code === locale;
        return (
          <button
            key={lang.code}
            type="button"
            role="radio"
            aria-checked={selected}
            disabled={pending}
            onClick={() => choose(lang.code)}
            className={`inline-flex items-center gap-xs rounded-full border px-md py-xs text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:opacity-60 ${
              selected
                ? "border-transparent bg-inverse-surface text-on-inverse"
                : "border-hairline text-ink hover:bg-surface-tint"
            }`}
          >
            {selected ? <Check size={14} strokeWidth={3} /> : null}
            {lang.label}
          </button>
        );
      })}
    </div>
  );
}
