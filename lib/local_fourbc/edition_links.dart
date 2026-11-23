// Local file of the 4bc Wallet project (not part of upstream Stack Wallet).
// Added 24 Nov 2026. Licensed like the rest of this repository: GPL-3.0.
//
// Upstream's screens name upstream's own website, and link to upstream's terms
// of service and privacy policy. Those pages do not describe this edition. In
// the 4bc Wallet edition the same places name our own site and its two pages
// (the partner's word of 24 Nov 2026); every other edition keeps upstream's.
// The upstream files pass their own address through fourbcLink(), so that a
// search for "stackwallet.com" still finds every place.

import 'edition_notice.dart';

/// Our site, and the two pages the welcome and About screens link to.
const kFourbcWebsite = "https://4bcwallet.com";
const kFourbcTermsUrl = "https://4bcwallet.com/terms";
const kFourbcPrivacyUrl = "https://4bcwallet.com/privacy";

const _ours = {
  "https://stackwallet.com": kFourbcWebsite,
  "https://stackwallet.com/terms-of-service.html": kFourbcTermsUrl,
  "https://stackwallet.com/privacy-policy.html": kFourbcPrivacyUrl,
  // the site's name as written at the end of a sentence (Auto Backup)
  "stackwallet.com.": "4bcwallet.com.",
};

/// Our address for one of upstream's, in our edition; [upstream] itself otherwise.
String fourbcLink(String upstream) =>
    isFourbcEdition ? (_ours[upstream] ?? upstream) : upstream;
