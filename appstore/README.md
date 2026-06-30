# App Store submission (via ascelerate)

Prepared metadata + screenshots for App Store Connect. ascelerate is already
authenticated.

## Two manual prerequisites (can't be done by the ASC API)

1. **Create the app record** — App Store Connect → Apps → **+ → New App**:
   - Platform: iOS
   - Name: **Elek** (if taken, use **Elek – Ad Blocker** and update app-infos.json)
   - Primary language: English (U.S.)
   - Bundle ID: **com.bykclk.elek**
   - SKU: **elek-001**

2. **Upload a build** — in Xcode: scheme **Elek**, destination **Any iOS Device**,
   **Product → Archive → Distribute App → App Store Connect → Upload**.
   (Most reliable for a Network Extension app. Alternatively
   `ascelerate builds archive` then `ascelerate builds upload`.)

## Then run the rest with ascelerate

```sh
# metadata, screenshots, attach build, preflight
ascelerate run-workflow appstore/release.workflow

# age rating — learn the schema from an existing app, craft 4+, import:
ascelerate apps app-info age-rating export com.bykclk.homehealth   # see keys
ascelerate apps app-info age-rating import com.bykclk.elek --file appstore/age-rating.json

# encryption declaration (standard HTTPS/DoH is exempt)
ascelerate apps encryption com.bykclk.elek --create --description "Standard HTTPS/TLS (DNS-over-HTTPS) only"

# review notes + contact (notes text from docs/app-review-notes.md)
ascelerate apps review info com.bykclk.elek \
  --contact-email omerbuyukcelik@gmail.com \
  --demo-account-required false \
  --notes "See docs/app-review-notes.md"

# final submit (outward, irreversible-ish) — run explicitly
ascelerate apps review submit com.bykclk.elek
```

Files:
- `app-infos.json` — app name, subtitle, privacy policy URL
- `localizations.json` — description, keywords, promo, support URL
- `media/en-US/APP_IPHONE_67/` — 6.9" screenshots (1320×2868)
