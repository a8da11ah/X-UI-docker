# Zero-Rating Bypass Testing — Methodology Notes

Internal test plan for evaluating whether this X-UI/Xray proxy stack can be
used to disguise billable traffic as zero-rated traffic against our own
billing/DPI pipeline. Scope: **test SIM / lab PGW-DPI environment only**, not
live subscriber traffic. Goal: find and close gaps in the zero-rating
classifier before they're exploited in the wild.

## Classifiers to test

Which of these the bypass succeeds against tells us which layer of the
billing pipeline needs hardening.

| Classifier | How it decides "free" | Bypassable via this proxy? |
|---|---|---|
| **SNI-only matching** | Reads the TLS ClientHello SNI, checks against an allowlist | Yes — trivially. Set the proxy's outbound TLS SNI to the zero-rated domain while the actual destination/payload is anything else. |
| **IP/ASN allowlisting** | Matches destination IP against the zero-rated service's known ranges | Yes, if the proxy can be hosted on (or fronted through) an IP in that range — e.g. via a CDN the zero-rated service also uses. |
| **DNS-based** | Zero-rates whatever IP a specific DNS query resolves to | Yes, if the carrier's DNS resolver isn't cross-checked against the actual TLS session — spoof/poison the DNS answer for the zero-rated domain to point at the proxy. |
| **SNI + cert CN/SAN validation** | Confirms the presented certificate's CN matches the SNI, not just the SNI string | No — this closes the simple version of the attack. |
| **App-ID / DPI fingerprinting** | Traffic-pattern/protocol fingerprinting (packet sizes, TLS extension order, JA3, HTTP/2 SETTINGS frames) specific to the real app | Partially — harder, but Xray's REALITY transport exists specifically to mimic a real site's TLS fingerprint, so it's still a realistic attack surface to test. |

## Test configs to run against the lab DPI/billing pipeline

1. **SNI-only bypass** — set Xray's outbound/inbound `serverName` (SNI) to
   the zero-rated domain while proxying arbitrary traffic. Cheapest, fastest
   test; if this alone gets billed as free, that's the highest-priority gap.
2. **REALITY-based fronting** — Xray's REALITY transport steals a real
   site's TLS handshake fingerprint (cert, JA3, extension order) so DPI
   can't distinguish it from genuine traffic to that site. Stronger test
   than plain SNI spoofing.
3. **CDN domain fronting** — if the zero-rated service sits behind a shared
   CDN (Cloudflare/Fastly/Akamai), test whether routing through that CDN
   with a mismatched Host header still gets billed as zero-rated.
4. **DNS-response test** — on the test SIM's resolver path, check whether
   the PGW/DPI re-resolves and validates the destination IP against the
   SNI/domain, or trusts the DNS answer blindly.

## Measuring success

Run each variant on the test SIM, push a known volume of non-zero-rated
payload (e.g. a large file download) through the tunnel, and check:

- Whether the CDR (call detail record) / mediation platform logs it as
  zero-rated or billable
- Whether DPI/PCRF flagged an anomaly (protocol mismatch, unexpected
  payload size for that "app")

## Remediation if a bypass succeeds

Regardless of which vector worked, the fix is consistent: validate **SNI +
cert CN + destination IP/ASN together**, not any single check alone, and
layer in App-ID/DPI behavioral fingerprinting with anomaly detection on data
volume vs. expected usage pattern for that app — rather than relying on any
one static allowlist check.

## Open item

Concrete Xray REALITY inbound config for the fingerprint-mimicry test case
(#2 above) — not yet built out. Next step if the SNI-only test (#1) doesn't
fully account for what the lab DPI actually enforces.
