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
Elek sets up encrypted DNS (DNS-over-HTTPS) for your device and points it at its
own private resolver. The resolver blocks known ad and tracker domains and
resolves everything else normally. It is not a VPN — only DNS lookups are sent to
the resolver, never your traffic — and it keeps no logs.

• System-wide — works in every app and browser
• Encrypted — your DNS is resolved over DNS-over-HTTPS
• No logs — the resolver never records the domains you look up
• Private — it can only ever see a domain name, never your traffic or content
• Privacy-first — no account, no ads, no tracking, no data collection
• One tap — turn protection on or off with a single button

Elek does not collect, store, or sell your data. Privacy is the whole point.

Note: Elek uses the system "DNS Settings" (encrypted DNS) feature. The first time
you turn it on, iOS asks you to switch Elek on once under Settings › General ›
VPN & Device Management › DNS. The resolver is open source.

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
  (DNS lookups are sent to Elek's resolver only to answer them in real time; the
  resolver keeps no logs and stores nothing, and no data goes to the developer.)

## App Review Information
- Sign-in required: No
- Notes: paste docs/app-review-notes.md (include the privacy policy URL).
- Contact: omerbuyukcelik@gmail.com

## Export compliance
- Uses encryption: Yes, but only standard HTTPS/TLS (DNS-over-HTTPS).
  Typically "exempt" — choose the "only standard encryption" option in App Store
  Connect and no extra documentation is required.
