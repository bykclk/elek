import { BinaryFuse } from "./binaryfuse.ts";
import { parseFirstQuestion, buildNxdomain, minAnswerTTL, BLOCK_TTL } from "./dns.ts";

export interface ResolveDeps {
  blocklist: BinaryFuse;
  upstreamUrl: string;
  fetchImpl: typeof fetch;
}

export interface ResolveResult {
  body: Uint8Array;
  blocked: boolean;
  /// What to put in the HTTP Cache-Control header. RFC 8484 wants the freshness
  /// lifetime to track the answer's TTL; sending `no-store` (as we used to) makes
  /// clients re-ask us constantly.
  cacheControl?: string;
}

/// Core DoH logic, independent of the Worker runtime so it can be unit-tested:
/// if the queried name (or a parent suffix) is blocked, synthesize NXDOMAIN;
/// otherwise forward the raw query to the upstream DoH resolver and return its
/// answer verbatim. Nothing is logged.
export async function resolveQuery(query: Uint8Array, deps: ResolveDeps): Promise<ResolveResult> {
  const { blocklist, upstreamUrl, fetchImpl } = deps;
  const q = parseFirstQuestion(query);
  if (q && blocklist.blocks(q.name)) {
    return {
      body: buildNxdomain(query, q.qnameEnd),
      blocked: true,
      cacheControl: `max-age=${BLOCK_TTL}`,
    };
  }

  // Call via a local binding so `this` is not `deps` (Workers' global fetch
  // throws "Illegal invocation" if invoked as a method of another object).
  const resp = await fetchImpl(upstreamUrl, {
    method: "POST",
    headers: {
      "content-type": "application/dns-message",
      accept: "application/dns-message",
    },
    body: query,
  });
  if (!resp.ok) throw new Error(`upstream ${resp.status}`);
  const body = new Uint8Array(await resp.arrayBuffer());

  // Keep the upstream's freshness if it sent one; Cloudflare's resolver doesn't,
  // so fall back to the answer's own smallest TTL.
  let cacheControl = resp.headers.get("cache-control") ?? undefined;
  if (!cacheControl) {
    const ttl = minAnswerTTL(body);
    if (ttl !== null) cacheControl = `max-age=${ttl}`;
  }
  return { body, blocked: false, cacheControl };
}
