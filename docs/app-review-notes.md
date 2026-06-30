# App Review notes (paste into App Store Connect → App Review Information → Notes)

Elek is a privacy utility that blocks ads and trackers system-wide using an
on-device DNS proxy (NEDNSProxyProvider, the Network Extensions "DNS Proxy"
capability).

IMPORTANT: Network Extensions do not run in the iOS Simulator, so please test on
a physical device.

How to test
1. Launch the app. On first launch it downloads a public domain blocklist and
   compiles an on-device filter. A small blocklist is bundled so it also works
   offline.
2. Tap the large circular button labeled "Korumayı Aç" (Turkish for "Turn on
   protection").
3. iOS shows a system prompt asking to allow Elek to add DNS proxy
   configurations. Approve it and authenticate (Face ID / passcode).
4. The status changes to "Koruma aktif" ("Protection active"). Browse the web:
   ad/tracker domains are answered locally with NXDOMAIN; all other DNS queries
   are forwarded to Cloudflare over encrypted DNS-over-HTTPS.
5. The large number is the count of requests blocked today.
6. Tap the button again ("Korumayı Kapat" = "Turn off protection") to disable.

Privacy / data
- No account or login is required.
- The app collects no data and contains no analytics or advertising SDKs.
- Allowed DNS queries are forwarded encrypted to Cloudflare (1.1.1.1).
- The blocklist is downloaded from the public HaGeZi list directly to the user's
  device and compiled locally; it is not bundled or redistributed by us.
- Privacy policy: <YOUR PUBLISHED PRIVACY POLICY URL>

The user interface is in Turkish. Key strings:
- "Korumayı Aç" = Turn on protection
- "Korumayı Kapat" = Turn off protection
- "Koruma aktif" / "Koruma kapalı" = Protection active / off
- "bugün engellenen istek" = requests blocked today

Contact: omerbuyukcelik@gmail.com
