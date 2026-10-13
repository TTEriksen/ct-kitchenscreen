# Køkkenskærm – iPad and Android tablet app

The kitchen screen as a native Flutter app. The tablet itself is the kitchen printer: the app listens on port 9100 like a network ESC/POS or Star printer, reads every print job from the till, and shows the tickets on screen. No server or extra computer is needed.

It does the same as the browser version in the repository root:
- **Status bar:** waiting tickets, total dishes, oldest waiting time, printer status, clock.
- **Tickets:** large type, with allergens in a red box and notes highlighted. A receipt button on each ticket shows the original printout.
- **Navigation:** swipe or Forrige / Næste, with position dots. Zoom with A− / A+ from 80 % to 200 %.
- **Done and recall:** Færdig with an 8-second Fortryd (undo). Afsluttede lists finished tickets so they can be brought back.
- **Layout:** landscape shows tickets side by side, and portrait shows a grid that scrolls up and down.
- **Kiosk behaviour:** a chime on new tickets, full screen, and the screen kept on. Tickets are saved on the tablet, so a restart loses nothing.

## Connecting the till

1. Put the tablet on the same network as the till and give it a **fixed IP address**:
   - **iPad:** Settings › Wi-Fi › (i) › Configure IP › Manual.
   - **Android:** Wi-Fi › network › Edit › IP settings › Static.

   Or reserve the address in the router.
2. Open the app. Settings (sliders button) shows the tablet's IP addresses.
3. In the till, set the kitchen printer to a network printer at that IP, **port 9100**, type Epson TM-T88 / ESC/POS (or Star with Star Line selected in Settings).

The app must be open on screen to receive tickets: iOS and Android stop network listeners in apps running in the background. The app keeps the screen on for this reason. Use Guided Access (iPad) or screen pinning / a kiosk launcher (Android) to keep it in front.

To test without a till, press **Modtag testbon** in Settings, or send jobs from a computer on the same network:

```bash
node ../tools/send-test.js <tablet-ip> 9100 5
```

## Building

```bash
flutter test
```

```bash
flutter build apk --release
```

```bash
flutter build ios --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`. It is signed with the debug key, which is fine for installing directly on your own tablets. For Google Play, add a release keystore.

The iOS project signs with team `2DWWB8Z822` (automatic signing). Change it in Xcode under Runner › Signing & Capabilities if needed.

## Installing on the tablets

Connect the tablet with a cable, then:

```bash
flutter devices
```

```bash
flutter run --release -d <device-id>
```

- **iPad:** turn on Developer Mode (Settings › Privacy & Security › Developer Mode), unlock it and tap "Trust this computer". The first time, also allow the developer profile under Settings › General › VPN & Device Management.
- **Android:** turn on USB debugging (tap Build number 7 times, then Developer options › USB debugging). You can also install the APK directly with `adb install build/app/outputs/flutter-apk/app-release.apk`.

## Code

```
lib/main.dart                 starts the app full screen with the screen kept on
lib/src/kitchen.dart          tickets, settings, saving, and the port 9100 printer listener
lib/src/models.dart           ticket, print line and settings data
lib/src/printer/escpos.dart   ESC/POS and Star Line decoder, status replies
lib/src/printer/codepages.dart PC865, PC850, PC858, PC437, Windows-1252, UTF-8
lib/src/printer/parser.dart   reads table, guests, items, modifiers, allergens, notes
lib/src/printer/samples.dart  test tickets
lib/src/ui/                   kitchen screen, ticket card, settings (UNIPOS Staff colours)
test/widget_test.dart         decoder and parser tests
```
