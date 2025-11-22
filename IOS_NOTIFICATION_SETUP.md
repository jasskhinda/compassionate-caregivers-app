# iOS Notification Setup with OneSignal

## Prerequisites
- Apple Developer account (Team ID: 4U272DP588)
- APNs key quota must be available (wait 24-48 hours after deleting VU73STXP65)
- OneSignal account already created with App ID: `39bdbb79-5651-45e0-a7ef-52505feb88ca`

## Current Status
✅ OneSignal Flutter SDK integrated in app
✅ Android platform configured and working
❌ iOS platform pending APNs Authentication Key

## Steps to Complete iOS Setup (10 minutes)

### Step 1: Create APNs Authentication Key
1. Go to [Apple Developer Portal - Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Click the **+** button to create a new key
3. Enter a name: `CC App OneSignal Push Key`
4. Check the box for **Apple Push Notifications service (APNs)**
5. Click **Continue**, then **Register**
6. **Download the .p8 file** (you can only download this once!)
7. Note the **Key ID** (10-character string like `ABC123XYZ4`)
8. Note your **Team ID**: `4U272DP588`

### Step 2: Add iOS Platform to OneSignal
1. Go to [OneSignal Dashboard](https://dashboard.onesignal.com/)
2. Select your app: **Compassionate Caregivers**
3. Go to **Settings** → **Platforms**
4. Click **Add a Platform** → **Apple iOS**
5. Upload configuration:
   - **APNs Auth Key (.p8 file)**: Upload the file from Step 1
   - **Key ID**: Enter the 10-character Key ID from Step 1
   - **Team ID**: `4U272DP588`
   - **Bundle ID**: `com.ccgrhc.caregiver`
6. Click **Save**

### Step 3: Verify Configuration
1. The OneSignal dashboard should show iOS platform as **Configured**
2. No code changes needed - the app already has OneSignal integrated

## Testing iOS Notifications

1. Install app on physical iPhone via Xcode
2. Log in with a test account
3. Check Firestore to verify `oneSignalPlayerId` was saved:
   ```
   Users/{userId}/oneSignalPlayerId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```
4. From another device (web or mobile), send a chat message to the test account
5. You should receive a native iOS notification with banner, badge, and sound

## Troubleshooting

### No notification received
- Check OneSignal dashboard → **Audience** → **All Users** to verify the iOS device appears
- Check Firebase Functions logs for any errors: `firebase functions:log`
- Verify the app has notification permissions: Settings → Compassionate Caregivers → Notifications

### "Invalid APNs credentials" error
- Ensure the Key ID and Team ID are correct
- Ensure the .p8 file was uploaded correctly
- Try re-uploading the APNs key in OneSignal dashboard

### Player ID not saved to Firestore
- Check Flutter logs for OneSignal initialization errors
- Verify `OneSignal.initialize()` is called in [main.dart](lib/main.dart#L71)
- Verify login saves Player ID in [login_ui.dart](lib/presentation/auth/login/login_ui.dart#L130-L145)

## Important Notes

- **Do not delete this APNs key** - it's the only one available for your team
- The APNs key works for both production and development environments
- Once configured, iOS notifications will work identically to Android (no code differences)
- The same Cloud Functions handle both Android and iOS notifications

## Files Modified for OneSignal Integration

1. **pubspec.yaml**: Added `onesignal_flutter: ^5.2.9`
2. **lib/main.dart**: OneSignal initialization (lines 69-81)
3. **lib/presentation/auth/login/login_ui.dart**: Save OneSignal Player ID (lines 124-160)
4. **functions/index.js**: Use OneSignal REST API for notifications
5. **lib/presentation/main/bottomBarScreens/notification_screen.dart**: Handle notification taps (lines 200-227)

No changes needed for iOS specifically - the OneSignal SDK handles platform differences automatically.
