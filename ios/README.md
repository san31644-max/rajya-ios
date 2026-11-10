# Rajya — native iPhone and iPad app

SwiftUI screens, PDFKit reading and URLSession JSON networking. There is no WebView, embedded website, JavaScript runtime, or HTML UI in this target. The existing PHP service supplies accounts, AI and saved data; the three reference PDFs are bundled and work without a network connection or sign-in.

Apple Team ID: `B5U69WW3Q3`. Provisional bundle ID: `lk.keducation.rajya` (confirm/register it in your Apple Developer account). Minimum iOS: 17.0. The first iOS marketing version is 1.0.0; Android versions are independent.

## Implemented source

- Native burgundy/gold home screen and five-tab navigation, Dynamic Type and reduced-motion-aware entry animation.
- Offline library with three original PDFs / 977 pages, PDFKit pinch zoom, in-document text search, page jumps, source links, page bookmarks and native sharing.
- Native sign-in/registration using existing account APIs, CSRF headers and isolated in-memory session cookies; reauthenticate after relaunch.
- Source provision search, draft/review status and source-page navigation.
- Courses, lessons, completion, procedure guides, practice questions and server-scored answers.
- Timed self-assessments, answer autosave, resume and results.
- AI chat, language/mode selection, saved conversations, photo picker, explicit third-party AI consent, native source-page links, sharing and editable answer reporting.
- Private notes/drafts with edit/delete/share, letter template forms and account deletion.

## Build with your Codemagic account

1. Upload the contents of the prepared `rajya-native-ios-source.zip` to a **private** Git repository. Its root contains `codemagic.yaml`, `ios/`, and the required preparation script. Keep those paths intact. This kit excludes the PHP server, credentials and Android signing keys.
2. Add that repository in Codemagic and choose the YAML configuration.
3. Run **ios-simulator** first. It generates `ios/Rajya.xcodeproj` using XcodeGen, compiles the actual Swift app and runs unit tests on an available iPhone simulator. No Apple signing secrets are needed for that workflow.
4. In Codemagic Team settings → Code signing identities, upload/fetch an App Store distribution certificate and matching provisioning profile for `lk.keducation.rajya`, team `B5U69WW3Q3`. Add API keys directly to Codemagic’s secure Apple Developer integration; never put them in this repository or chat.
5. Run **ios-app-store-archive** to produce a signed IPA. The build number increments from Codemagic's build number; ensure it exceeds any number already uploaded for this app version.
6. Create the matching App Store Connect app record, upload a successfully signed build, and test on iPhone/iPad through TestFlight before review. Public release is not automated by this configuration.

The simulator workflow and signed workflow are separate: only archive a revision after its simulator checks pass. On a Mac, prepare with `node scripts/prepare-ios.mjs`, install XcodeGen if necessary, run `xcodegen generate --spec ios/project.yml`, then open `ios/Rajya.xcodeproj`.

## Current verification limits and release work

This source was prepared on Windows without an Apple SDK. No successful Xcode compile, XCTest run, simulator/device run, signed IPA, TestFlight upload or App Store submission is claimed. Run the Codemagic simulator workflow and fix any compile/runtime failures before signing. The supplied archive is source code, not an installable app.

Premium access currently follows the existing server's membership state. **No StoreKit purchasing, receipt verification, restore purchases, or bank-transfer checkout is implemented in this iOS target.** The owner most recently requested bank transfers rather than Apple purchases. That unresolved purchase model is a release blocker for the paid AI/exam features under the usual App Store rules; changing to native UI does not change the rules. Do not represent this build as App Store-ready. Do not add bank-transfer instructions to unlock digital features in storefronts where they are disallowed. A StoreKit integration requires product IDs, server-side verified entitlements and refund/renewal handling, or a documented applicable Apple exception must be established first.

Verify the hosted API, AI provider, subscription gates, account deletion, photo uploads, session expiry and simultaneous exam-answer saves on the real service. The app uses selected-library photos only, not direct camera capture, and does not include the website's pixel masking editor. Choose an already redacted image. Photos already in a saved chat show a photo indicator rather than image thumbnails in this first native version. PDF search depends on the original PDFs' text encoding; scanned or incorrectly encoded Sinhala text may not match.

Review every UI in Sinhala, English and Tamil, Dynamic Type, VoiceOver, landscape, iPad split view, keyboard, large photos, offline launch, interrupted requests, background/resume during an exam, logout and deletion. Account-specific content is cleared when signing out or switching accounts. Recheck OCR, lesson content, question correctness and amendment coverage with a qualified content reviewer.

Review `PrivacyInfo.xcprivacy` and complete App Store Connect’s privacy declarations against actual operations and provider contracts. Disclose account identifiers, name/email, user text/photos, learning activity, AI-report support data, membership/purchase history and operational network logs as applicable. The draft manifest is not a substitute for owner attestation. Update the public privacy policy for iOS and any eventual Apple payment processing. No broad photo-library, camera, location, tracking or advertising permission is requested.

Official references: [Codemagic native iOS](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/), [Apple review/payment rules](https://developer.apple.com/app-store/review/guidelines/), [account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/), [privacy details](https://developer.apple.com/app-store/app-privacy-details/).
