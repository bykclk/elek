# App Review notes (paste into App Store Connect → App Review Information → Notes)

Elek is a privacy utility that blocks ads and trackers system-wide using an
on-device DNS filter, implemented as a Network Extension packet tunnel
(NEPacketTunnelProvider). The tunnel is local-only: it has no VPN server, routes
ONLY DNS queries (a single virtual resolver IP) into the extension, and answers
them on-device. No user traffic or data leaves the device to the developer.

IMPORTANT: Network Extensions do not run in the iOS Simulator, so please test on
a physical device.

How to test
1. Launch the app. On first launch it downloads a public domain blocklist and
   compiles an on-device filter. A small blocklist is bundled so it also works
   offline.
2. Tap the large circular button. A short explainer appears; tap "Continue".
3. iOS shows the standard system prompt asking to allow Elek to add a VPN
   configuration (this is the on-device DNS filter). Approve it.
4. The status changes to "Protection active". Browse the web: ad/tracker
   domains are answered locally with NXDOMAIN; all other DNS queries are
   resolved over encrypted DNS-over-HTTPS (Cloudflare). Non-DNS traffic never
   enters the tunnel.
5. The large number shows requests blocked today and increases while browsing.
6. Tap the button again to turn protection off.

If protection cannot be enabled, the app shows an alert with the reason (it
never fails silently).

Privacy / data
- No account or login is required.
- The app collects no data and contains no analytics or advertising SDKs.
- The "VPN" is a local packet tunnel used only to filter DNS on-device; there is
  no server side.
- Allowed DNS queries are forwarded encrypted to Cloudflare (1.1.1.1).
- The blocklist is downloaded from the public HaGeZi list directly to the user's
  device and compiled locally; it is not bundled or redistributed by us.
- Privacy policy: https://bykclk.github.io/elek/privacy-policy.html

Contact: omerbuyukcelik@gmail.com
