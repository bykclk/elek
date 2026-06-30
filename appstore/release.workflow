# Elek — App Store submission workflow.
# Run AFTER (1) the app record exists in App Store Connect and (2) a build has
# been uploaded and finished processing.
#   ascelerate run-workflow appstore/release.workflow
#
# Age rating + review notes are handled separately (see appstore/README.md),
# because they need an interactive questionnaire / long text.

apps create-version com.bykclk.elek 1.0
apps app-info update com.bykclk.elek --primary-category UTILITIES
apps app-info import com.bykclk.elek --file appstore/app-infos.json
apps localizations import com.bykclk.elek --file appstore/localizations.json
apps media upload com.bykclk.elek appstore/media/
apps build attach-latest com.bykclk.elek
apps review preflight com.bykclk.elek
# Review submit is intentionally left out of the workflow — run it explicitly
# after a final check:
#   ascelerate apps review submit com.bykclk.elek
