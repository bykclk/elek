# Elek — Privacy Policy

**Effective date:** 30 June 2026

Elek is an iOS app that blocks ads and trackers system-wide using on-device DNS
filtering. Your privacy is the entire point of the app, so the policy is short:
**Elek does not collect, store, sell, or share any personal data.** There are no
accounts, no analytics, no advertising, and no tracking.

## How Elek works and what happens to your data

- **DNS queries are processed on your device.** When protection is on, Elek
  inspects the domain names your device looks up and decides whether to block or
  allow each one. This decision happens entirely on your device.
- **The filter runs as a local VPN configuration.** iOS shows Elek as a VPN
  because that is the mechanism apps use to filter DNS on-device. Elek's tunnel
  has no server: only DNS queries enter it, they are processed on your device,
  and no other traffic is routed through it.
- **Blocked queries never leave your device.** If a domain is on the blocklist,
  Elek answers it locally (with an `NXDOMAIN` response). Nothing is sent anywhere.
- **Allowed queries are forwarded encrypted.** Domains that are not blocked are
  resolved by forwarding them to Cloudflare over encrypted DNS-over-HTTPS
  (`https://1.1.1.1/dns-query`). Those queries are handled under
  [Cloudflare's privacy policy](https://www.cloudflare.com/privacypolicy/). The
  Elek developer does not see, log, or store them.
- **The blocklist is downloaded to your device.** Elek fetches a public domain
  blocklist (the [HaGeZi list](https://github.com/hagezi/dns-blocklists)) directly
  from its source to your device and compiles it locally. This network request
  goes to that source, not to us.
- **The "blocked today" counter is local.** The number shown in the app is stored
  only on your device (in the app's App Group container) and is never transmitted.

## Data we collect

None. Elek does not collect personal data, advertising identifiers, contact
information, location, or usage analytics. It contains no third-party analytics,
advertising, or crash-reporting SDKs. Elek does not track you across apps or
websites.

## Third-party services

- **Cloudflare** — used as the encrypted DNS (DoH) resolver for allowed queries.
- **HaGeZi blocklist (via GitHub)** — the source of the domain blocklist your
  device downloads.

Elek has no servers of its own and sends no data to its developer.

## Children

Elek is not directed at children and collects no data from anyone.

## Changes

If this policy changes, the updated version will be posted here with a new
effective date.

## Contact

Questions: **omerbuyukcelik@gmail.com**
