# WiFi Check - Enable Ads Guide

**Target Date:** October 2026 (or whenever you're ready)

This guide walks you through adding ads and in-app purchase (Remove Ads) to WiFi Check. The app was launched ad-free; this document preserves the steps to monetize later.

---

## Step 1: Create a Google AdMob Account

1. Go to [admob.google.com](https://admob.google.com)
2. Sign in with your Google account
3. Register your app:
   - Apps > Add App > iOS
   - Enter "WiFi Check" and your App Store URL
4. Create a **Banner** ad unit:
   - Ad units > Add ad unit > Banner
   - Name: `WiFi Check - Banner`
   - Copy the **Ad Unit ID** (e.g., `ca-app-pub-XXXXXXXX/XXXXXXXXXX`)

## Step 2: Add Google Mobile Ads SDK

### Via Swift Package Manager:
1. In Xcode: File > Add Package Dependencies
2. URL: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
3. Add `GoogleMobileAds` to your target

### Configure Info.plist:
Add your AdMob App ID:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXX~XXXXXXXXXX</string>
```

## Step 3: Create the Ad Banner View

Create `WiFiCheck/Views/AdBannerView.swift`:

```swift
import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .first
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
```

## Step 4: Add the Ad Banner to Tab Views

In each tab view (WiFiInfoTab, SpeedTestTab, NetworkScanTab, SettingsView), add:

```swift
AdBannerView(adUnitID: "YOUR_AD_UNIT_ID")
    .frame(height: 50)
    .padding(.top, 4)
```

## Step 5: Re-add In-App Purchase (Remove Ads)

1. **App Store Connect:** Create a non-consumable IAP with product ID `com.wificheck.removeads` ($1.99)
2. Re-create `PurchaseViewModel.swift` with StoreKit 2 purchase flow
3. Re-create `PurchaseSheet.swift` with the purchase UI
4. Add `adsRemoved` back to `UserDefaultsManager`
5. Wrap ad banners with `if !purchaseVM.adsRemoved { ... }`
6. Add "Remove Ads" row back to SettingsView Account card
7. Add `StoreKit.framework` back to the project

## Step 6: Add App Tracking Transparency (Optional)

If you want personalized ads:

1. Add `import AppTrackingTransparency` to TabRootView
2. Request ATT permission on appear:
   ```swift
   ATTrackingManager.requestTrackingAuthorization { _ in }
   ```
3. Add to build settings:
   ```
   INFOPLIST_KEY_NSUserTrackingUsageDescription = "This allows us to show you relevant ads."
   ```

## Step 7: Update Privacy Policy

Update `privacy.html` on wifi-check.app to disclose:
- Google AdMob collects device identifiers for ad personalization
- Users can opt out via App Tracking Transparency
- The "Remove Ads" purchase removes all ad tracking

Update the in-app PrivacySummarySheet in SettingsView.swift accordingly.

## Step 8: Build and Upload

1. Product > Clean Build Folder (Shift+Cmd+K)
2. Product > Archive
3. Distribute App > App Store Connect > Upload
4. In App Store Connect, update App Privacy to reflect ad tracking

---

## Quick Reference

| Item | Value |
|------|-------|
| AdMob SDK | `https://github.com/googleads/swift-package-manager-google-mobile-ads` |
| IAP Product ID | `com.wificheck.removeads` |
| IAP Price | $1.99 |
| Bundle ID | `Latest.WifiCheck` |
| Privacy Policy URL | `https://www.wifi-check.app/privacy.html` |
| Terms URL | `https://www.wifi-check.app/terms.html` |
