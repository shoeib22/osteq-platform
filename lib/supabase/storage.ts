import { supabaseUrl } from "./env";

/**
 * Public URL for an object in a public Supabase Storage bucket. Building this directly
 * from the project URL (Supabase's own public-URL format) rather than through a
 * Supabase client, since generating it requires no auth/session — instantiating a
 * client just to string-concatenate a URL adds an unnecessary browser/server client
 * distinction for something that doesn't need one.
 */
export function getPublicUrl(bucket: string, path: string): string {
  return `${supabaseUrl()}/storage/v1/object/public/${bucket}/${path}`;
}
