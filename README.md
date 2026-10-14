# CT Kitchenscreen

A kitchen display that pretends to be a network kitchen printer. Point the till's kitchen printer at this device's IP address (port 9100) and every ticket that would have been printed appears on the touch screen instead: table, guests, ticket number, waiter, courses, dishes, modifiers, allergens and notes, laid out large enough to read across the kitchen.

- **Printer emulation:** raw TCP on port 9100 (JetDirect), ESC/POS (Epson and compatibles) or Star Line mode. It answers the till's status requests, so tills that check "is the printer online?" keep printing.
- **Tickets:** each paper cut in a print job becomes its own ticket. The ticket is read into table, guests, ticket number, waiter, time, courses, items with modifiers, allergens and notes. The original printout is kept as well and can be shown on any ticket with the receipt button.
- **Allergens** show in a red box at the top of the ticket, and the affected dish gets a warning icon. Allergens are found by keyword (editable in Settings) and by anything the till prints in red or white-on-black.
- **Status bar** with how many tickets are waiting, total dishes, oldest ticket's waiting time, printer status and a clock.
- **Waiting time** per ticket: green, then orange after 10 min, red after 15 min (both adjustable).
- **Scrolling**: swipe, or use the large Forrige / Næste buttons. Position dots show where you are.
- **Zoom** with A− / A+ from 80 % to 200 %, remembered per screen.
- **Færdig** removes a ticket, with an 8-second **Fortryd** (undo). **Afsluttede** lists finished tickets so any of them can be brought back with **Hent tilbage**.
- **Any screen size**: landscape shows tickets side by side, and portrait screens get a grid that scrolls up and down. It switches automatically or can be fixed in Settings.
- Several screens can show the same tickets: open the page on each screen and they stay in sync.
- New-ticket chime, the screen kept awake, and works offline. It has no dependencies beyond Node.js.

- **Colours**: Settings › Farver has Mørk / Lys / Automatisk (follows the screen's own setting), five palettes (CTpos, Brasserie, Hav, Skov, Høj kontrast) and Egen, where you pick an accent colour and a background tone. Every other colour is calculated for both light and dark mode and adjusted until text, buttons, allergens and status colours reach at least 4.5:1 contrast. With a red accent, modifiers and notes switch to blue so they never look like allergens.

The screen text is in Danish. Logo, icons and default colours come from the CTpos design system.

There is also a native **iPad and Android tablet app** in [`flutter_app/`](flutter_app/README.md). The tablet itself is the printer, so no server is needed.

## Requirements

- Node.js 18 or newer (no `npm install` needed: no dependencies)
- A browser on the touch screen (Chromium, Chrome or Edge in kiosk mode)

## Quick start

```bash
npm start
```

Open http://localhost:8080 on the screen. To send a test ticket the way a till would:

```bash
npm run send-test
```

or press **Modtag testbon** in Settings.

## Connecting the till

1. Give the kitchen screen device a **static IP address** (see below), e.g. `192.168.1.50`.
2. In the till's back office, set the kitchen printer to a **network printer** at that IP, **port 9100**, type **Epson TM-T88 / ESC/POS** (or a Star model with Star Line mode selected in Settings).
3. Send a ticket from the till. It appears on the screen within a second.

If letters like æ, ø and å come out wrong, change **Tegnsæt** in Settings (PC865 Nordic is the usual choice for Danish tills). If the layout doesn't split a till's tickets the way you want, the **Original bon** view still shows exactly what was printed.

To test a captured print job byte for byte:

```bash
node tools/send-test.js 192.168.1.50 9100 --file job.bin
```

## Setting a static IP address

The IP address is set in the operating system, not in the app. The app listens on all addresses (`0.0.0.0`) by default. Settings shows the addresses the device currently has.

**Raspberry Pi OS (Bookworm) / Ubuntu with NetworkManager**

```bash
nmcli con show
```

```bash
sudo nmcli con mod "Wired connection 1" ipv4.method manual ipv4.addresses 192.168.1.50/24 ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.1
```

```bash
sudo nmcli con up "Wired connection 1"
```

**Windows** (run as administrator; check the adapter name with `netsh interface show interface`)

```bat
netsh interface ip set address name="Ethernet" static 192.168.1.50 255.255.255.0 192.168.1.1
```

Alternatively, reserve the address for the device's MAC address in the router's DHCP settings.

## Running it as a kiosk

**Raspberry Pi / Linux**

1. Copy the folder to `/opt/ct-kitchenscreen`.
2. Install the service: `sudo cp deploy/kitchenscreen.service /etc/systemd/system/` (edit `User` first), then `sudo systemctl enable --now kitchenscreen`.
3. Autostart `deploy/kiosk.sh` in the desktop session; it opens Chromium full screen and turns off screen blanking.

**Windows**

Put a shortcut to `deploy\start-windows.bat` in `shell:startup`. It starts the server and opens Edge in kiosk mode.

Browsers only play sound after the screen has been touched once. If the chime is blocked, a **Tryk for lyd** button appears in the top bar. The kiosk scripts pass a flag that allows sound straight away.

## Settings

Tap the settings button (sliders icon) in the top bar. Settings are stored in `data/settings.json`:

| Setting | Default | |
| --- | --- | --- |
| Printernavn | Køkkenprinter 1 | Shown in the top bar |
| Lyt på adresse | 0.0.0.0 | Which address to accept print jobs on |
| Port | 9100 | Printer port; changing it restarts the listener |
| Protokol | ESC/POS | Or Star Line |
| Tegnsæt | Automatisk | Follows the till's code page, PC865 by default, and detects UTF-8 |
| Tekststørrelse | 100 % | Default zoom for new screens |
| Gul / Rød efter | 10 / 15 min | Waiting-time colours |
| Layout | Automatisk | Or always landscape / portrait |
| Bonvisning | Opdelt | Or always the original printout |
| Gem afsluttede | 2 hours | How long finished tickets can be recalled |
| Lyd ved ny bon | on | Chime on every new ticket |
| Allergen-ord | gluten, laktose, nødder, … | Words that flag a line as an allergen |

The web port (8080) can be changed in `data/settings.json` or with environment variables. Restart the program afterwards. `KDS_WEB_PORT`, `KDS_PRINTER_PORT` and `KDS_DATA_DIR` override the stored values.

Tickets are stored in `data/tickets.json`, so a restart or power cut doesn't lose what's on screen.

## Project layout

```
server/
  index.js       web server, live updates (server-sent events), API
  printer.js     TCP port 9100 listener: collects print jobs, answers status requests
  escpos.js      ESC/POS and Star Line decoder: bytes → styled text lines, split on cuts
  codepages.js   PC865, PC850, PC858, PC437, Windows-1252, ESC R national sets, UTF-8
  parser.js      text lines → table, guests, items, modifiers, allergens, notes
  store.js       tickets and settings, saved to data/
  samples.js     sample tickets for testing
public/          the screen (plain HTML, CSS and JavaScript)
tools/send-test.js   sends tickets to a screen over TCP, like a till
test/            parser and decoder tests (npm test)
deploy/          systemd service, Chromium kiosk script, Windows start script
design/          the design canvas the screen is built from
```

## API

| | |
| --- | --- |
| `GET /api/events` | Server-sent events: the full state on every change |
| `GET /api/state` | Active and finished tickets, settings, printer status |
| `POST /api/tickets/:id/done` | Mark a ticket done |
| `POST /api/tickets/:id/restore` | Bring a finished ticket back |
| `DELETE /api/tickets` | Remove all tickets |
| `POST /api/test` | Add a sample ticket |
| `GET` / `PUT /api/settings` | Read or change settings |

The API has no login, so keep the device on the restaurant's internal network.
