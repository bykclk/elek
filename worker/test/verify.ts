// Host verification for the TypeScript Binary Fuse port — the same check we ran
// for the Swift reader: load the committed SEED blocklist.bin (our own data, not
// HaGeZi) and assert every seed domain is reported blocked (no false negatives),
// plus that the DoH resolver synthesizes a correct NXDOMAIN and forwards allowed
// queries. Run with: node test/verify.ts   (Node >= 23 strips types natively)

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { BinaryFuse, fnv1a64 } from "../src/binaryfuse.ts";
import { parseFirstQuestion, buildNxdomain, base64urlToBytes } from "../src/dns.ts";
import { resolveQuery } from "../src/resolver.ts";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", ".."); // repo root

let failures = 0;
function check(cond: boolean, msg: string): void {
  if (!cond) {
    failures++;
    console.error("  ✗ " + msg);
  }
}

// ---------------------------------------------------------------------------
// 1) Binary Fuse byte-compatibility against the committed seed filter.
// ---------------------------------------------------------------------------
const bin = new Uint8Array(readFileSync(join(root, "tools/seed.bin")));
const fuse = new BinaryFuse(bin);

const seedText = readFileSync(join(root, "tools/seed.txt"), "utf8");
const seedDomains = seedText
  .split("\n")
  .map((l) => l.trim())
  .filter((l) => l.length > 0 && !l.startsWith("#"));

console.log(`seed domains: ${seedDomains.length}`);

let missed = 0;
for (const d of seedDomains) {
  if (!fuse.contains(fnv1a64(d))) {
    missed++;
    console.error(`  ✗ false negative (contains): ${d}`);
  }
  if (!fuse.blocks(d)) {
    missed++;
    console.error(`  ✗ false negative (blocks): ${d}`);
  }
  // Parent-suffix matching: a subdomain of a blocked domain is blocked too.
  if (!fuse.blocks("ads-tracker." + d)) {
    missed++;
    console.error(`  ✗ suffix match failed: ads-tracker.${d}`);
  }
}
check(missed === 0, `${missed} false negatives across ${seedDomains.length} seed domains`);
if (missed === 0) console.log(`  ✓ all ${seedDomains.length} seed domains + subdomains matched`);

// Domains that must NOT be blocked (Binary Fuse 8-bit has a ~0.4%/label false
// positive rate, so this is a sanity check, not a guarantee — report if hit).
const shouldPass = [
  "example.com", "wikipedia.org", "github.com", "apple.com",
  "cloudflare.com", "mozilla.org", "openstreetmap.org", "kernel.org",
];
const fp = shouldPass.filter((d) => fuse.blocks(d));
if (fp.length) console.log(`  ⚠ false positives (expected on a tiny seed): ${fp.join(", ")}`);
else console.log(`  ✓ ${shouldPass.length} common domains correctly not blocked`);

// ---------------------------------------------------------------------------
// 2) DNS wire helpers + resolver behavior.
// ---------------------------------------------------------------------------
function buildQuery(name: string, id = 0x1234): Uint8Array {
  const parts: number[] = [
    (id >> 8) & 0xff, id & 0xff, // ID
    0x01, 0x00,                  // flags: RD
    0x00, 0x01,                  // QDCOUNT = 1
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // AN/NS/AR = 0
  ];
  for (const label of name.split(".")) {
    parts.push(label.length);
    for (let i = 0; i < label.length; i++) parts.push(label.charCodeAt(i));
  }
  parts.push(0x00);       // root label
  parts.push(0x00, 0x01); // QTYPE = A
  parts.push(0x00, 0x01); // QCLASS = IN
  return new Uint8Array(parts);
}

const blockedName = seedDomains[0];
const q = buildQuery(blockedName, 0xabcd);
const parsed = parseFirstQuestion(q);
check(parsed?.name === blockedName, `parseFirstQuestion name (${parsed?.name} === ${blockedName})`);

const nx = buildNxdomain(q, parsed!.qnameEnd);
check((nx[2] & 0x80) !== 0, "NXDOMAIN QR bit set");
check((nx[3] & 0x0f) === 0x03, "NXDOMAIN Rcode = 3");
check(nx[0] === 0xab && nx[1] === 0xcd, "NXDOMAIN echoes query ID");
check(nx[6] === 0 && nx[7] === 0, "NXDOMAIN ANCOUNT = 0");

// GET base64url round-trip parses to the same question.
const b64 = Buffer.from(q).toString("base64url");
const decoded = base64urlToBytes(b64);
check(parseFirstQuestion(decoded)?.name === blockedName, "base64url GET decode");

// resolveQuery: blocked -> NXDOMAIN, upstream never touched.
const blockedRes = await resolveQuery(q, {
  blocklist: fuse,
  upstreamUrl: "http://unused",
  fetchImpl: async () => {
    throw new Error("upstream must not be called for a blocked query");
  },
});
check(blockedRes.blocked === true, "blocked query flagged blocked");
check((blockedRes.body[3] & 0x0f) === 0x03, "blocked query returns NXDOMAIN");

// resolveQuery: allowed -> forwarded to upstream.
let forwarded = false;
const allowRes = await resolveQuery(buildQuery("example.com"), {
  blocklist: fuse,
  upstreamUrl: "http://unused",
  fetchImpl: async () => {
    forwarded = true;
    return new Response(new Uint8Array([0xde, 0xad, 0xbe, 0xef]), { status: 200 });
  },
});
check(!allowRes.blocked && forwarded, "allowed query forwarded to upstream");
check(allowRes.body.length === 4, "allowed query returns upstream body verbatim");

// ---------------------------------------------------------------------------
console.log("");
if (failures === 0) {
  console.log("✅ all checks passed");
} else {
  console.error(`❌ ${failures} check(s) failed`);
  process.exit(1);
}
