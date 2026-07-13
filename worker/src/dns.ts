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

/// Build an NXDOMAIN (Rcode 3) response echoing the query's ID and question.
export function buildNxdomain(msg: Uint8Array, qnameEnd: number): Uint8Array {
  const questionEnd = qnameEnd + 4; // include QTYPE + QCLASS
  const out = new Uint8Array(questionEnd); // 12-byte header + question only
  out.set(msg.subarray(0, questionEnd));

  out[2] = msg[2] | 0x80; // QR=1 (response); keep Opcode + RD from the query
  out[3] = 0x80 | 0x03; // RA=1, Rcode=3 (NXDOMAIN)
  out[4] = 0; out[5] = 1; // QDCOUNT = 1
  out[6] = 0; out[7] = 0; // ANCOUNT = 0
  out[8] = 0; out[9] = 0; // NSCOUNT = 0
  out[10] = 0; out[11] = 0; // ARCOUNT = 0 (any OPT/EDNS from the query is dropped)
  return out;
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
