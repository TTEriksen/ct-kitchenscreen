# App Store: Køkkenskærm (iPad)

Everything for the App Store and TestFlight listing. The screenshots in this folder are 2752 × 2064, the 13" iPad size App Store Connect asks for. It scales them down for smaller iPads. Make them again with `flutter_app/tool/screenshots.sh`.

| Screenshot | Shows |
| --- | --- |
| `01-kitchen.png` | The kitchen screen: tickets with allergens, notes, waiting times (green/orange/red), the status bar |
| `02-large.png` | A ticket tapped large: the ticket beside the original printout, with Færdig and Print |
| `03-finished.png` | Afsluttede: bring back a ticket that was finished by mistake |
| `04-colours.png` | Settings › Farver: five palettes and your own, dark and light |
| `05-light.png` | Light mode with the Hav palette |

## App Store Connect: create the app (once)

1. **Bundle ID**: Certificates, Identifiers & Profiles › Identifiers. Check that `dk.ctconsult.ctKitchenscreen` exists (Xcode's automatic signing normally registered it). If it doesn't, add it as an App ID.
2. **New app**: App Store Connect › Apps › + › New App:
   - Platform: **iOS**
   - Name: **CTpos Køkkenskærm**, or another name if that one is taken. Names must be unique on the App Store.
   - Primary language: **Danish**
   - Bundle ID: **dk.ctconsult.ctKitchenscreen**
   - SKU: **ctkitchenscreen**
   - User access: Full access
3. **Upload the build**: either run `flutter_app/tool/release_ios.sh`, or open `flutter_app/build/ios/archive/Runner.xcarchive` in Xcode and choose Distribute App › App Store Connect.
4. **TestFlight**: once Apple has processed the build (usually 5–30 minutes), add yourself and testers under TestFlight › Internal Testing. Internal testers can install straight away. External testers need a short beta review first.

For the build to upload, Xcode must be signed in under **Xcode › Settings › Accounts** with an Apple ID in team 2DWWB8Z822. The alternative is an App Store Connect API key (see the comments in `release_ios.sh`).

## Listing texts (Danish)

**Name** (max 30): CTpos Køkkenskærm

**Subtitle** (max 30): Køkkenprinter på en tablet

**Promotional text** (max 170):
Bonnerne fra kassen kommer direkte på skærmen i køkkenet: store tal, tydelige allergier og noter, ventetid i farver, og en rigtig printer når I har brug for papir.

**Description**:

> Køkkenskærm gør en iPad til køkkenets printer. Kassen sender bonnerne til tabletten, præcis som den ellers ville printe dem, og de vises med det samme på skærmen. Du behøver ingen server og ingen ekstra kasse.
>
> - Virker med kasser der printer til en netværksprinter (ESC/POS eller Star, port 9100)
> - Bord, gæster, bonnummer, tjener, retter, tilvalg og noter med stor tekst, der kan læses på afstand
> - Allergier står i en tydelig rød boks øverst på bonnen
> - Ventetid i farver: grøn, orange efter 10 minutter og rød efter 15 (kan justeres)
> - Tryk på en bon for at se den stort sammen med den originale udskrift
> - Færdig med fortryd, og Afsluttede, hvor du kan hente en bon tilbage
> - Zoom fra 80 til 200 %, liggende eller stående skærm
> - Print på en rigtig køkkenprinter, enten hver bon eller kun når I trykker Print. Bonnen sættes op til hele papirets bredde.
> - Mørk, lys eller automatisk visning, fem farvepaletter eller dine egne farver, og jeres eget logo i topbjælken
> - Lyd ved ny bon, og skærmen holdes tændt
>
> Bonnerne gemmes kun på tabletten, og intet sendes videre til os.

**Keywords** (max 100, comma-separated, no spaces after commas):
køkkenskærm,KDS,bonprinter,køkkenprinter,restaurant,ESC/POS,ordre,bonner,allergi,café,kasse

**Category**: Business (primary), Food & Drink (secondary)

**Age rating**: 4+ (no objectionable content)

**Price**: your choice (free or paid)

**Support URL**: *[your support page, e.g. https://tte.dk]*

**Privacy policy URL** (required): *[a page saying the app stores tickets only on the device and collects no personal data]*

## App Privacy

**Data Not Collected.** The app sends nothing to the developer. Tickets, settings and the venue logo are stored only on the iPad. Network traffic only goes between the till and the iPad, and from the iPad to a kitchen printer the user sets up.

## Export compliance

The app declares `ITSAppUsesNonExemptEncryption = NO` (it uses no encryption), so TestFlight doesn't ask for each build.

## Notes for App Review

> The app receives kitchen tickets from a point-of-sale system over the local network (it acts as a network printer on port 9100). To try it without a till: open Settings (the gear button at the top right), scroll to "Drift" and tap **Modtag testbon**. Each tap adds a sample ticket. Tap a ticket to see it large, and tap **Færdig** to finish it. The app asks for Local Network access because the till connects to it, and for Photos only if the user chooses their own logo.
