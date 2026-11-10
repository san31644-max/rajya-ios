# Rajya ? native iOS app

Native SwiftUI iPhone/iPad app for K Education (Pvt) Ltd.

See [iOS setup and Codemagic instructions](ios/README.md).

The native simulator build passed all six unit tests, and Codemagic produced a signed IPA. The **ios-app-store-archive** workflow now builds and uploads using the saved **K education Codemagic** integration. It requires Apple signing profiles and does not automatically submit for App Store review. Apple upload/processing and physical-device testing remain to be verified.
