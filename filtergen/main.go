// filtergen builds an on-device Binary Fuse (8-bit) blocklist from a domain
// list (e.g. a HaGeZi list). It runs at BUILD TIME on the Mac, never on device.
//
// Output format (little-endian) — the Swift reader (Blocklist.swift) must match
// byte-for-byte:
//
//	magic "BFF8"      4 bytes
//	version           u8  = 1
//	hashType          u8  = 1   (fnv1a64 over ASCII-lowercased UTF-8, no trailing dot)
//	reserved          u16 = 0
//	seed              u64
//	segmentLength     u32
//	segmentLengthMask u32
//	segmentCountLength u32
//	fingerprintCount  u32
//	fingerprints      [fingerprintCount] u8
//
// The fingerprint array is xorfilter's BinaryFuse[uint8].Fingerprints, and the
// other fields are the parameters its Contains() needs. SegmentCount is not
// written because Contains() does not use it.
//
// Usage:
//
//	go run . -in hagezi.txt -out ../Elek/Resources/blocklist.bin
//	cat hagezi.txt | go run . -out blocklist.bin
package main

import (
	"bufio"
	"encoding/binary"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/FastFilter/xorfilter"
)

const (
	magic      = "BFF8"
	version    = 1
	hashFNV1a  = 1
	fnvOffset  = 14695981039346656037
	fnvPrime   = 1099511628211
)

func main() {
	inPath := flag.String("in", "", "input domain list (default: stdin)")
	outPath := flag.String("out", "blocklist.bin", "output .bin path")
	flag.Parse()

	in := os.Stdin
	if *inPath != "" {
		f, err := os.Open(*inPath)
		if err != nil {
			fatal("open input: %v", err)
		}
		defer f.Close()
		in = f
	}

	domains := readDomains(in)
	if len(domains) == 0 {
		fatal("no domains parsed from input")
	}

	// fnv1a64 keys, de-duplicated (Binary Fuse construction needs distinct keys).
	keySet := make(map[uint64]struct{}, len(domains))
	keys := make([]uint64, 0, len(domains))
	for d := range domains {
		k := fnv1a64(d)
		if _, ok := keySet[k]; ok {
			continue
		}
		keySet[k] = struct{}{}
		keys = append(keys, k)
	}

	filter, err := xorfilter.NewBinaryFuse[uint8](keys)
	if err != nil {
		fatal("build binary fuse: %v", err)
	}

	if err := writeFilter(*outPath, filter); err != nil {
		fatal("write output: %v", err)
	}

	fmt.Printf("wrote %s: %d domains, %d unique keys, %d fingerprints (%d bytes)\n",
		*outPath, len(domains), len(keys), len(filter.Fingerprints), len(filter.Fingerprints))
}

// readDomains parses a domain list tolerantly: skips blanks and # comments,
// accepts hosts-format lines (takes the last field), strips adblock decorations
// (||domain^), leading "*.", trailing dots, and ASCII-lowercases.
func readDomains(r *os.File) map[string]struct{} {
	out := make(map[string]struct{})
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "!") {
			continue
		}
		// Strip inline comments.
		if i := strings.IndexAny(line, "#"); i >= 0 {
			line = strings.TrimSpace(line[:i])
		}
		// hosts format: "0.0.0.0 ads.example.com" -> take last token.
		if fields := strings.Fields(line); len(fields) > 1 {
			line = fields[len(fields)-1]
		}
		// adblock decorations.
		line = strings.TrimPrefix(line, "||")
		line = strings.TrimSuffix(line, "^")
		line = strings.TrimPrefix(line, "*.")
		line = strings.TrimSuffix(line, ".")
		line = asciiLower(line)
		if line == "" || !isPlausibleDomain(line) {
			continue
		}
		out[line] = struct{}{}
	}
	return out
}

func isPlausibleDomain(s string) bool {
	if !strings.Contains(s, ".") {
		return false
	}
	for i := 0; i < len(s); i++ {
		c := s[i]
		ok := (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.' || c == '-' || c == '_'
		if !ok {
			return false
		}
	}
	return true
}

func asciiLower(s string) string {
	b := []byte(s)
	for i := range b {
		if b[i] >= 'A' && b[i] <= 'Z' {
			b[i] += 32
		}
	}
	return string(b)
}

// fnv1a64 over ASCII-lowercased UTF-8 bytes. Must match Blocklist.swift exactly.
func fnv1a64(s string) uint64 {
	h := uint64(fnvOffset)
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			c += 32
		}
		h ^= uint64(c)
		h *= fnvPrime
	}
	return h
}

func writeFilter(path string, f *xorfilter.BinaryFuse[uint8]) error {
	out, err := os.Create(path)
	if err != nil {
		return err
	}
	defer out.Close()
	w := bufio.NewWriter(out)

	if _, err := w.WriteString(magic); err != nil {
		return err
	}
	if err := w.WriteByte(version); err != nil {
		return err
	}
	if err := w.WriteByte(hashFNV1a); err != nil {
		return err
	}
	le := binary.LittleEndian
	put := func(v any) error { return binary.Write(w, le, v) }

	if err := put(uint16(0)); err != nil { // reserved
		return err
	}
	if err := put(f.Seed); err != nil {
		return err
	}
	if err := put(f.SegmentLength); err != nil {
		return err
	}
	if err := put(f.SegmentLengthMask); err != nil {
		return err
	}
	if err := put(f.SegmentCountLength); err != nil {
		return err
	}
	if err := put(uint32(len(f.Fingerprints))); err != nil {
		return err
	}
	if _, err := w.Write(f.Fingerprints); err != nil {
		return err
	}
	return w.Flush()
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "filtergen: "+format+"\n", args...)
	os.Exit(1)
}
