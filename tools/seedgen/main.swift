import Foundation

// Build-time tool: compile the bundled seed blocklist.bin from a domain list
// using the same Swift BinaryFuseBuilder the app uses on-device. Compiled and
// run by scripts/build-seed.sh — no separate Go toolchain needed.
//
// usage: seedgen <seed.txt> <out.bin>

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: seedgen <seed.txt> <out.bin>\n".data(using: .utf8)!)
    exit(2)
}
let text = (try? String(contentsOfFile: args[1], encoding: .utf8)) ?? ""
let domains = DomainListParser.parse(text)
guard let data = BinaryFuseBuilder.buildBlocklist(domains: domains) else {
    FileHandle.standardError.write("seedgen: build failed (empty input?)\n".data(using: .utf8)!)
    exit(1)
}
do {
    try data.write(to: URL(fileURLWithPath: args[2]))
    print("seedgen: wrote \(args[2]) — \(domains.count) domains, \(data.count) bytes")
} catch {
    FileHandle.standardError.write("seedgen: write failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
