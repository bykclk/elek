# App Review notes (paste into App Store Connect → App Review Information → Notes)

Elek is a privacy utility that blocks ads and trackers system-wide by configuring
encrypted DNS. It uses NEDNSSettingsManager (the "DNS Settings" capability) to
install a DNS-over-HTTPS configuration that points the system at Elek's own DoH
resolver, which blocks known ad/tracker domains and forwards everything else.
There is NO VPN and NO Network Extension packet tunnel. Elek keeps no logs.

IMPORTANT: DNS configurations do not take effect in the iOS Simulator, so please
test on a physical device.

How to test
1. Launch the app and tap the large circular button. A short explainer appears;
   tap "Continue".
2. Elek installs its encrypted-DNS configuration. iOS does not activate an
   app-provided DNS configuration automatically, so the app then shows a banner:
   "One last step".
3. Follow it: Settings › General › VPN & Device Management › DNS, and choose
   "Elek". (This is a normal, one-time step for app-configured encrypted DNS.)
4. Return to Elek — the status shows "Protection active". Browse the web (for
   example https://d3ward.github.io/toolz/adblock): ad/tracker domains are
   blocked (answered with NXDOMAIN by the resolver) and everything else resolves
   normally.
5. To turn protection off, tap the button again (this removes the DNS
   configuration), or turn it off under the same Settings path.

If a step fails, the app shows an alert with the reason (it never fails silently).

Privacy / data
- No account or login is required.
- The app collects no data, keeps no logs, and contains no analytics or
  advertising SDKs.
- Elek is NOT a VPN. It uses the system "DNS Settings" (encrypted DNS)
  capability; only DNS lookups are sent to the resolver, never user traffic.
- The resolver is open source (github.com/bykclk/elek, worker/ folder), runs on
  Cloudflare, and logs nothing. Allowed lookups are forwarded to Cloudflare's
  public DNS over DoH.
- The ad/tracker blocklist (open-source HaGeZi list) is enforced on the resolver;
  it is not downloaded to the device.
- Privacy policy: https://bykclk.github.io/elek/privacy-policy.html

Contact: omerbuyukcelik@gmail.com
