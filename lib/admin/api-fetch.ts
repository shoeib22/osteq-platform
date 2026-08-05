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
  const hostname = host.split(":")[0];
  // Bare IPv4 addresses can never hold a publicly trusted TLS cert, so they're always
  // plain HTTP here — this app currently has no domain/Caddy TLS in front of it. Only
  // treat an actual hostname (a real domain) as HTTPS.
  const isIpv4 = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(hostname);
  const protocol = hostname === "localhost" || isIpv4 ? "http" : "https";
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
