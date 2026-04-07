# WiFiCheck Feature Backlog

## 🔴 Planned for v0.3 (Next Submission — still pre-release)

### Device Naming & Memory (Network Scan)
**Goal:** Allow users to name unrecognized devices. Names persist across scans indefinitely.

**Key behaviors:**
- After scan, unknown/unrecognized devices show a "Tap to name →" prompt
- User assigns a friendly name (e.g. "Dad's laptop", "Smart Plug - Kitchen")
- Name saved to SwiftData, keyed by **hostname** (primary) + MAC (fallback)
- On next scan: if hostname matches → auto-show saved name with a small "You named this" badge
- Apple device challenge: use mDNS hostname (`Santoshs-iPhone.local`) as stable ID since MAC rotates
- Detect Apple devices via mDNS service types (`_apple-mobdev2._tcp`, etc.)

**UX:**
```
📱 Santosh's iPhone    [You named this]
📺 Living Room TV      [You named this]
❓ 192.168.1.45        Unknown Device  [Tap to name →]
🔴 No hostname         Unrecognized    [⚠️ Tap to name →]
```

**Storage:** SwiftData model `SavedDevice { hostname, mac, userLabel, firstSeen, lastSeen }`

---

## 🟡 Planned for v1.0+ (Post public launch)

### AI Device Fingerprinting
- Use MAC OUI lookup + hostname patterns to auto-identify device type
- Flag truly unknown devices with security warning
- Fully on-device, no data leaves network

### Live Activities for Test Runs
- Lock screen / Dynamic Island shows test progress: `🧪 87/123 ✅ 3 ❌`
- Updates live, dismisses when done

---

## ✅ Submission Checklist (Run Before Every App Store Submission)

> This checklist should be triggered automatically when archiving.

1. **Run full UI test suite** (`xcodebuild test`) — must pass 123/123
2. **Smoke test on real device** — manually verify Sign in with Apple, core tabs, speed test
3. **Check for placeholder values** — App Store URL, dummy IDs, test credentials
4. **Update release notes** (see RELEASE_NOTES.md)
5. **Confirm with Santosh** before uploading to App Store Connect
6. **Archive + upload** only after explicit confirmation

---
