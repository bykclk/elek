# Elek — Privacy Policy

**Effective date:** 14 July 2026

Elek is an iOS app that blocks ads and trackers system-wide using encrypted DNS.
Your privacy is the entire point of the app, so the policy is short: **Elek does
not collect, store, sell, or share any personal data, and keeps no logs.** There
are no accounts, no analytics, no advertising, and no tracking.

## How Elek works and what happens to your data

- **Elek configures encrypted DNS — it is not a VPN.** When you turn Elek on, it
  installs a DNS-over-HTTPS configuration and asks you to switch it on in
  Settings. iOS then sends your device's DNS lookups — and only DNS lookups — to
  Elek's resolver. Your actual traffic (the pages you load, the messages and
  files you send and receive) does **not** go through Elek.
- **Your DNS lookups are answered by Elek's resolver.** The resolver is a small,
  open-source program running on Cloudflare's network. For each lookup it sees
  only the domain name being requested (for example `example.com`), decides
  whether it is a known ad or tracker domain, and either blocks it (returns an
  `NXDOMAIN` "no such domain" answer) or forwards it to Cloudflare's public DNS
  and returns the result.
- **The resolver keeps no logs.** It does not record the domains you look up,
  your IP address, or anything else. Its complete source code is public
  (see [github.com/bykclk/elek](https://github.com/bykclk/elek), the `worker/`
  folder), so this can be independently verified.
- **What the resolver can and cannot see.** Because DNS carries only host names,
  the resolver technically sees the domain names your device looks up, the
  network address the request comes from, and the time. It can **never** see the
  content of your traffic, the full web addresses (paths) you visit, your
  messages, or anything inside your apps. Elek logs and stores **none** of this.
- **Allowed lookups are resolved over encrypted DNS.** Domains that are not
  blocked are forwarded to Cloudflare's public DNS over an encrypted connection
  and handled under
  [Cloudflare's privacy policy](https://www.cloudflare.com/privacypolicy/).
- **No account, no identifiers.** Elek requires no sign-in and assigns you no
  identifier.

## Data we collect

None. Elek does not collect personal data, advertising identifiers, contact
information, location, or usage analytics. It contains no third-party analytics,
advertising, or crash-reporting SDKs. Elek does not track you across apps or
websites. The DNS lookups sent to Elek's resolver are used only to answer them in
real time and are never logged or stored.

## Third-party services

- **Cloudflare** — hosts Elek's DNS resolver and is the upstream provider for
  resolving allowed lookups.
- **HaGeZi blocklist** — the open-source list of ad/tracker domains that Elek's
  resolver enforces ([github.com/hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists)).

Elek sends no data to its developer, and the developer keeps no logs.

## Children

Elek is not directed at children and collects no data from anyone.

## Changes

If this policy changes, the updated version will be posted here with a new
effective date.

## Contact

Questions: **omerbuyukcelik@gmail.com**
