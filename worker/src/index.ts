import blocklistData from "../blocklist.bin";
import { BinaryFuse } from "./binaryfuse.ts";
import { resolveQuery } from "./resolver.ts";
import { base64urlToBytes } from "./dns.ts";

interface Env {
  /// If set, requests must carry this token as a path segment
  /// (serverURL = https://host/<AUTH_TOKEN>/dns-query). Weak abuse protection
  /// only — the token ships inside the app binary and is extractable.
  AUTH_TOKEN?: string;
  /// Upstream DoH resolver. Defaults to Cloudflare (1.1.1.1).
  UPSTREAM_DOH?: string;
}

const DNS_CT = "application/dns-message";

// Built once per isolate (blocklist.bin embedded at deploy time).
const blocklist = new BinaryFuse(new Uint8Array(blocklistData as ArrayBuffer));

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    // Hostname (not IP literal): the server has no DNS-bootstrap loop the way the
    // on-device tunnel did, and a normal cert works in local dev + on the edge.
    const upstream = env.UPSTREAM_DOH || "https://cloudflare-dns.com/dns-query";

    // Optional token gate.
    if (env.AUTH_TOKEN && !url.pathname.split("/").includes(env.AUTH_TOKEN)) {
      return new Response("forbidden", { status: 403 });
    }
    if (!url.pathname.endsWith("/dns-query")) {
      return new Response("not found", { status: 404 });
    }

    // Decode the DNS query from POST body or GET ?dns= (RFC 8484).
    let query: Uint8Array;
    if (request.method === "POST") {
      if (request.headers.get("content-type") !== DNS_CT) {
        return new Response("unsupported media type", { status: 415 });
      }
      query = new Uint8Array(await request.arrayBuffer());
    } else if (request.method === "GET") {
      const dns = url.searchParams.get("dns");
      if (!dns) return new Response("missing dns parameter", { status: 400 });
      try {
        query = base64urlToBytes(dns);
      } catch {
        return new Response("bad dns parameter", { status: 400 });
      }
    } else {
      return new Response("method not allowed", { status: 405, headers: { allow: "GET, POST" } });
    }

    if (query.length < 12 || query.length > 4096) {
      return new Response("bad request", { status: 400 });
    }

    try {
      const { body, cacheControl } = await resolveQuery(query, {
        blocklist,
        upstreamUrl: upstream,
        fetchImpl: fetch,
      });
      return new Response(body, {
        status: 200,
        headers: {
          "content-type": DNS_CT,
          ...(cacheControl ? { "cache-control": cacheControl } : {}),
        },
      });
    } catch {
      return new Response("upstream error", { status: 502 });
    }
  },
};
