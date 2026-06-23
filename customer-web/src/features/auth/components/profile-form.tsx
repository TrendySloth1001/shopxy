"use client";

import { useState, type FormEvent } from "react";
import { useAuth } from "../auth-context";
import { updateProfileSchema } from "../schema";
import { Field } from "./field";
import { SubmitButton } from "./submit-button";
import { Banner } from "./banner";
import { AvatarPicker } from "./avatar-picker";

/** Customer profile: name, contact phone, and email-notification preference. */
export function ProfileForm() {
  const { user, updateProfile } = useAuth();
  const [name, setName] = useState(user?.name ?? "");
  const [phoneNumber, setPhoneNumber] = useState(user?.phoneNumber ?? "");
  const [emailNotifications, setEmailNotifications] = useState(
    user?.emailNotifications ?? true,
  );
  const [fieldErrors, setFieldErrors] = useState<{
    name?: string;
    phoneNumber?: string;
  }>({});
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSaved(false);
    const parsed = updateProfileSchema.safeParse({
      name,
      phoneNumber,
      emailNotifications,
    });
    if (!parsed.success) {
      const f = parsed.error.flatten().fieldErrors;
      setFieldErrors({ name: f.name?.[0], phoneNumber: f.phoneNumber?.[0] });
      return;
    }
    setFieldErrors({});
    setSubmitting(true);
    try {
      await updateProfile(parsed.data);
      setSaved(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save your changes.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-lg">
      {error ? <Banner variant="error" message={error} /> : null}
      {saved ? <Banner variant="success" message="Profile saved." /> : null}

      <AvatarPicker />

      <Field
        label="Your name"
        value={name}
        onChange={(e) => {
          setName(e.target.value);
          setSaved(false);
        }}
        error={fieldErrors.name}
      />
      <Field
        label="Phone number"
        type="tel"
        autoComplete="tel"
        value={phoneNumber}
        onChange={(e) => {
          setPhoneNumber(e.target.value);
          setSaved(false);
        }}
        error={fieldErrors.phoneNumber}
      />
      <label className="flex cursor-pointer items-start gap-sm border-t border-hairline pt-md">
        <input
          type="checkbox"
          checked={emailNotifications}
          onChange={(e) => {
            setEmailNotifications(e.target.checked);
            setSaved(false);
          }}
          className="mt-[2px] size-4 shrink-0 accent-brand"
        />
        <span className="flex flex-col">
          <span className="text-body-md text-ink">Email notifications</span>
          <span className="text-body-sm text-muted">
            Order updates, security alerts and account activity.
          </span>
        </span>
      </label>

      <div className="pt-sm">
        <SubmitButton loading={submitting} block={false}>
          Save changes
        </SubmitButton>
      </div>
    </form>
  );
}
