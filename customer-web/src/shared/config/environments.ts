import "server-only";
import { env } from "./env";

export type BackendEnvironment = {
  id: string;
  label: string;
  description: string;
  baseUrl: string;
};

export const BACKEND_ENVIRONMENTS: readonly BackendEnvironment[] = [
  {
    id: "production",
    label: "Production",
    description: "Live shops and real money",
    baseUrl: "https://backendshopxy.cloudnsofts.com",
  },
  {
    id: "tunnel",
    label: "Dev tunnel",
    description: "The shared dev backend",
    baseUrl: "https://qjhcp0ph-3003.inc1.devtunnels.ms",
  },
  {
    id: "local",
    label: "Local",
    description: "localhost:3003, alongside this Next server",
    baseUrl: "http://localhost:3003",
  },
] as const;

export const ENV_COOKIE = "sxc_env";

export function environmentById(id: string | undefined | null) {
  if (!id) return undefined;
  return BACKEND_ENVIRONMENTS.find((e) => e.id === id);
}

export function environmentMatching(baseUrl: string) {
  const normalise = (u: string) => u.trim().toLowerCase().replace(/\/+$/, "");
  const needle = normalise(baseUrl);
  return BACKEND_ENVIRONMENTS.find((e) => normalise(e.baseUrl) === needle);
}

export const DEFAULT_BACKEND_BASE_URL = env.API_BASE_URL;
