import {
  userAddressSchema,
  addressListSchema,
  type UserAddress,
  type AddressFormValues,
} from "./types";

async function jsonOrThrow<T>(
  res: Response,
  parse: (raw: unknown) => T,
  fallback: string,
): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export async function fetchAddresses(): Promise<UserAddress[]> {
  const res = await fetch("/api/me/addresses", { cache: "no-store" });
  const { data } = await jsonOrThrow(
    res,
    (raw) => addressListSchema.parse(raw),
    "Could not load addresses.",
  );
  return data;
}

export async function createAddress(
  values: AddressFormValues,
): Promise<UserAddress> {
  const res = await fetch("/api/me/addresses", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(values),
  });
  return jsonOrThrow(
    res,
    (raw) => userAddressSchema.parse(raw),
    "Could not save address.",
  );
}

export async function updateAddress(
  id: string,
  values: Partial<AddressFormValues>,
): Promise<UserAddress> {
  const res = await fetch(`/api/me/addresses/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(values),
  });
  return jsonOrThrow(
    res,
    (raw) => userAddressSchema.parse(raw),
    "Could not update address.",
  );
}

export async function deleteAddress(id: string): Promise<void> {
  const res = await fetch(`/api/me/addresses/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    let message = "Could not delete address.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
}

export async function setDefaultAddress(id: string): Promise<void> {
  const res = await fetch(`/api/me/addresses/${id}/default`, {
    method: "POST",
  });
  if (!res.ok && res.status !== 204) {
    throw new Error("Could not set default address.");
  }
}
