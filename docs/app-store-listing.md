# App Store listing — Elek (draft)

> Fill these into App Store Connect. "Elek" alone may be taken; if so use the
> fallback name. English is the primary localization; a Turkish localization can
> be added later in App Store Connect.

## Name (max 30)
- Primary: **Elek**
- Fallback: **Elek – Ad Blocker**

## Subtitle (max 30)
System-wide ad & tracker blocker

## Promotional text (max 170, editable anytime)
Block ads and trackers across every app on your device. No account, no ads, no
data collection — just a faster, cleaner internet.

## Description
Elek is a privacy utility that blocks ads and trackers at the DNS level, across
your entire iPhone — not just one app, but every app and Safari.

How it works
Elek inspects your device's domain (DNS) lookups on-device. It blocks ad and
tracker domains locally and resolves everything else over encrypted
DNS-over-HTTPS. No traffic ever goes to the developer.

• System-wide — works in every app and browser
• On-device — blocking decisions happen on your phone
• Encrypted — allowed queries are resolved over DNS-over-HTTPS
• Transparent — see how many requests were blocked today
• Privacy-first — no account, no ads, no tracking, no data collection
• One tap — turn protection on or off with a single button

Elek does not collect, store, or sell your data. Privacy is the whole point.

Note: Elek uses a Network Extension (DNS Proxy) and asks for a system permission
the first time you turn it on. The blocklist is downloaded to your device from an
open-source list.

## Keywords (max 100, comma-separated, no spaces)
ad blocker,adblock,tracker,privacy,dns,anti-tracking,ads,block,security,no ads

## Support URL
https://github.com/bykclk/elek

## Marketing URL (optional)
(can be left blank)

## Privacy Policy URL
https://bykclk.github.io/elek/privacy-policy.html

## Category
- Primary: Utilities
- Secondary: Productivity

## Age rating
4+ (no ads, no user-generated content)

## App Privacy (nutrition label answers)
- Data collection: **No, we do not collect data from this app.**
  (On-device DNS is not sent to the developer; allowed queries go to Cloudflare
  over DoH but are not collected by us.)

## App Review Information
- Sign-in required: No
- Notes: paste docs/app-review-notes.md (include the privacy policy URL).
- Contact: omerbuyukcelik@gmail.com

## Export compliance
- Uses encryption: Yes, but only standard HTTPS/TLS (DNS-over-HTTPS).
  Typically "exempt" — choose the "only standard encryption" option in App Store
  Connect and no extra documentation is required.
