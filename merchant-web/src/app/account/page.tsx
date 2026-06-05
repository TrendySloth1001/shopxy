import { redirect } from "next/navigation";

// Account management now lives inside the dashboard shell. Keep this path as a
// permanent redirect so old links / bookmarks still resolve.
export default function AccountPage() {
  redirect("/dashboard/profile");
}
