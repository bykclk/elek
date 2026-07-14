// Minimal DNS wire helpers: read the first question name, and synthesize an
// NXDOMAIN response for a blocked name. We never build answer records — a
// blocked lookup just gets "no such domain".

export interface Question {
  name: string;
  /// Byte offset of the QTYPE field (question ends 4 bytes later: QTYPE+QCLASS).
  qnameEnd: number;
  qtype: number;
}

/// Parse the first question. Returns null on malformed input.
export function parseFirstQuestion(msg: Uint8Array): Question | null {
  if (msg.length < 12) return null;
  const qdcount = (msg[4] << 8) | msg[5];
  if (qdcount < 1) return null;

  let i = 12;
  const labels: string[] = [];
  while (i < msg.length) {
    const len = msg[i];
    if (len === 0) {
      i += 1;
      break;
    }
    if ((len & 0xc0) !== 0) return null; // compression pointers are illegal in a question
    i += 1;
    if (i + len > msg.length) return null;
    let label = "";
    for (let j = 0; j < len; j++) {
      let b = msg[i + j];
      if (b >= 65 && b <= 90) b += 32; // ASCII A-Z -> a-z
      label += String.fromCharCode(b);
    }
    labels.push(label);
    i += len;
  }
  if (i + 4 > msg.length) return null; // room for QTYPE + QCLASS
  const qtype = (msg[i] << 8) | msg[i + 1];
  return { name: labels.join("."), qnameEnd: i, qtype };
}

/// How long (seconds) a client may cache a blocked answer.
///
/// This is the SOA MINIMUM, which is what RFC 2308 resolvers use as the
/// negative-cache TTL. It matters a lot: without an SOA the client cannot cache
/// "no such domain" at all, so every blocked lookup comes back to us on every
/// single request — and blocked ad/tracker domains are exactly the ones apps
/// retry most often.
export const BLOCK_TTL = 3600;

function encodeName(name: string): number[] {
  const out: number[] = [];
  for (const label of name.split(".")) {
    if (!label) continue;
    out.push(label.length);
    for (let i = 0; i < label.length; i++) out.push(label.charCodeAt(i));
  }
  out.push(0); // root
  return out;
}

function u32(n: number): number[] {
  return [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff];
}

/// Build an NXDOMAIN (Rcode 3) response echoing the query's ID and question, with
/// an SOA in the authority section so the answer is negatively cacheable.
export function buildNxdomain(msg: Uint8Array, qnameEnd: number): Uint8Array {
  const questionEnd = qnameEnd + 4; // include QTYPE + QCLASS

  const rdata = [
    ...encodeName("elek.invalid"), // MNAME
    ...encodeName("hostmaster.elek.invalid"), // RNAME
    ...u32(1), // SERIAL
    ...u32(3600), // REFRESH
    ...u32(600), // RETRY
    ...u32(604800), // EXPIRE
    ...u32(BLOCK_TTL), // MINIMUM — the negative-cache TTL
  ];
  const soa = [
    0xc0, 0x0c, // NAME: compression pointer to the question's QNAME (offset 12)
    0x00, 0x06, // TYPE = SOA
    0x00, 0x01, // CLASS = IN
    ...u32(BLOCK_TTL), // TTL
    (rdata.length >> 8) & 0xff, rdata.length & 0xff, // RDLENGTH
    ...rdata,
  ];

  const out = new Uint8Array(questionEnd + soa.length);
  out.set(msg.subarray(0, questionEnd));

  out[2] = msg[2] | 0x80; // QR=1 (response); keep Opcode + RD from the query
  out[3] = 0x80 | 0x03; // RA=1, Rcode=3 (NXDOMAIN)
  out[4] = 0; out[5] = 1; // QDCOUNT = 1
  out[6] = 0; out[7] = 0; // ANCOUNT = 0
  out[8] = 0; out[9] = 1; // NSCOUNT = 1 (the SOA below)
  out[10] = 0; out[11] = 0; // ARCOUNT = 0 (any OPT/EDNS from the query is dropped)
  out.set(soa, questionEnd);
  return out;
}

/// Advance past a DNS name. Returns the offset just after it, or -1 if malformed.
function skipName(msg: Uint8Array, i: number): number {
  while (i < msg.length) {
    const len = msg[i];
    if (len === 0) return i + 1;
    if ((len & 0xc0) === 0xc0) return i + 2; // a compression pointer ends the name
    i += 1 + len;
  }
  return -1;
}

/// Smallest TTL across the answer + authority records, or null if there are none
/// (or the message is malformed). Per RFC 8484 §5.1 the DoH response's HTTP
/// freshness must not outlive the DNS data it carries — upstreams often send no
/// Cache-Control at all, and without one an intermediary could heuristically
/// cache a DNS answer well past its TTL.
export function minAnswerTTL(msg: Uint8Array): number | null {
  if (msg.length < 12) return null;
  const records = ((msg[6] << 8) | msg[7]) + ((msg[8] << 8) | msg[9]); // AN + NS
  if (records === 0) return null;

  let i = 12;
  const qd = (msg[4] << 8) | msg[5];
  for (let q = 0; q < qd; q++) {
    const end = skipName(msg, i);
    if (end < 0) return null;
    i = end + 4; // QTYPE + QCLASS
  }

  let min: number | null = null;
  for (let r = 0; r < records; r++) {
    const end = skipName(msg, i);
    if (end < 0 || end + 10 > msg.length) return null;
    i = end;
    const ttl = ((msg[i + 4] << 24) | (msg[i + 5] << 16) | (msg[i + 6] << 8) | msg[i + 7]) >>> 0;
    const rdlength = (msg[i + 8] << 8) | msg[i + 9];
    i += 10 + rdlength;
    if (i > msg.length) return null;
    if (min === null || ttl < min) min = ttl;
  }
  return min;
}

/// Decode a base64url string (RFC 8484 GET `?dns=`) into bytes.
export function base64urlToBytes(s: string): Uint8Array {
  let b64 = s.replace(/-/g, "+").replace(/_/g, "/");
  while (b64.length % 4 !== 0) b64 += "=";
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
