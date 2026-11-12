# Native App Store screenshots

Run **Capture native App Store screenshots** under the repository's GitHub Actions tab. This unsigned simulator workflow uses the actual native app and live public course/question APIs. It does not use a customer account, sample membership, mock screen or website capture, and does not submit or upload anything to Apple.

The two jobs capture an iPhone 16 Pro (1206 × 2622) and a 13-inch iPad Pro (2064 × 2752), or an available supported simulator with an equivalent accepted screen size. They use a light appearance and a standard 9:41 status bar.

Download each job's screenshot artifact. Review the numbered JPG files in `iPhone-medium/` and `iPad-13-inch/` and upload only complete, correctly rendered screens to the corresponding device category in App Store Connect. The images are direct native screenshots converted to high-quality JPEG solely to remove the alpha channel; their content and dimensions are unchanged. Logs are provided separately for diagnosis, not for store upload.

Captures show the home screen, offline library, Winaya reference PDF page 10, learning paths, a source-based lesson, practice questions and procedure guides. The source-edition/draft notices remain visible. Screenshots do not show private account or paid AI features because no account credentials are used.

Re-run after a visible UI change, and review every image before uploading. If the public learning service is unavailable, the job fails rather than publishing blank/loading/error screens as completed screenshots.

Reference: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
