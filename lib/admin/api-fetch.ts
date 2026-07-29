import { cookies, headers } from "next/headers";

interface AdminApiResult<T> {
  data?: T;
  error?: string;
}

export async function adminApiFetch<T>(
  path: string,
  options: { method?: string; body?: unknown } = {},
): Promise<AdminApiResult<T>> {
  const host = (await headers()).get("host") ?? "localhost:3000";
  const protocol = host.startsWith("localhost") || host.startsWith("127.0.0.1") ? "http" : "https";
  const cookieHeader = (await cookies())
    .getAll()
    .map((c) => `${c.name}=${c.value}`)
    .join("; ");

  const res = await fetch(`${protocol}://${host}${path}`, {
    method: options.method ?? "GET",
    headers: {
      "Content-Type": "application/json",
      Cookie: cookieHeader,
    },
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
    cache: "no-store",
  });

  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    return { error: typeof json.error === "string" ? json.error : "Request failed." };
  }
  return { data: json as T };
}
