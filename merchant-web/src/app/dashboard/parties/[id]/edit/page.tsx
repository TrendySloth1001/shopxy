"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { PartyEditor } from "@/features/parties/party-editor";
import { getParty } from "@/features/parties/api";
import type { Party } from "@/features/parties/schema";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function EditPartyPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const [party, setParty] = useState<Party | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const p = await getParty(id);
        if (active) setParty(p);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the customer.");
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!party) return <FormSkeleton />;

  return <PartyEditor existing={party} />;
}
