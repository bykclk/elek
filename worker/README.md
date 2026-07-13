# Elek DNS — Cloudflare Worker (DoH resolver)

A DNS-over-HTTPS (RFC 8484) resolver that blocks ads/trackers and forwards
everything else. The iOS app points the system at it via `NEDNSSettings`
(no VPN, no extension, App Store–compliant). **It logs nothing.**

## How it works

1. Receives a DoH request (`POST /…/dns-query` or `GET …/dns-query?dns=`).
2. Reads the queried name and checks it (and each parent suffix) against an
   embedded Binary Fuse filter — the same `blocklist.bin` format the app uses,
   built by the same Swift builder (`src/binaryfuse.ts` is a verified port).
3. Blocked → returns `NXDOMAIN`. Otherwise → forwards the raw query to the
   upstream DoH resolver (`1.1.1.1` by default) and returns its answer verbatim.

What the resolver can see: the queried **hostname**, source IP, and time.
What it cannot see: page content, URLs/paths, request bodies — DNS carries only
"which domain," never "what was sent." This build stores **none** of it.

## Blocklist (GPL)

The full list is [HaGeZi](https://github.com/hagezi/dns-blocklists) (GPLv3).
`worker/blocklist.bin` is **generated, gitignored, and never committed** —
committing the derived filter would be redistribution. Serving DNS answers from
it on our own resolver is use, not conveying (GPLv3 is not AGPL). The small
committed `Elek/Resources/blocklist.bin` is our own hand-authored seed only.

Rebuild before deploying (or after HaGeZi updates):

```sh
npm run build-blocklist     # fetches HaGeZi, builds worker/blocklist.bin
```

## Develop & deploy

```sh
npm install
npm test                    # host-verify the Binary Fuse port (no network)
npm run build-blocklist     # produce worker/blocklist.bin
npm run dev                 # local resolver at http://localhost:8787/dns-query
npm run deploy              # wrangler deploy (needs `wrangler login`)
```

Test a local query (blocked example — googlesyndication.com, RFC 8484 GET):

```sh
# byte 3's low nibble should be 3 (NXDOMAIN)
curl -s 'http://localhost:8787/dns-query?dns=q80BAAABAAAAAAAAEWdvb2dsZXN5bmRpY2F0aW9uA2NvbQAAAQAB' \
  | xxd | head
# an allowed domain (example.com) is forwarded and resolves normally:
curl -s 'http://localhost:8787/dns-query?dns=q80BAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE' \
  | xxd | head
```

## Config

| Var | Purpose |
|-----|---------|
| `AUTH_TOKEN` (secret) | If set, requests must include it as a path segment: `https://host/<token>/dns-query`. Weak abuse protection only — it ships inside the app binary. Set with `wrangler secret put AUTH_TOKEN`. |
| `UPSTREAM_DOH` (var) | Upstream DoH resolver. Default `https://1.1.1.1/dns-query`. |
