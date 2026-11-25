# iRdp

iRdp lets you connect to a Mac with standard Microsoft Remote Desktop clients
(Windows App, `mstsc.exe`, FreeRDP). It implements an RDP 10 server in Swift 6.4
that shares only the screen image, the mouse and the keyboard.

It has two parts:

- **iRdp.app**, a menu bar app with settings for the port, the login type and
  the shared resources. It starts and stops the service.
- **iRdpService**, a LaunchAgent that accepts RDP connections. It captures the
  screen with ScreenCaptureKit and injects input with Quartz events.

## Features

- RDP 10 server: X.224 negotiation, TLS security layer, MCS/GCC, licensing,
  capability exchange, fast-path input and output.
- Screen updates with the RDP graphics pipeline (RDPGFX over the dynamic
  virtual channel) and hardware H.264 (AVC420, VideoToolbox, low-latency rate
  control) for clients that support it, such as Windows App and mstsc. Client
  frame acknowledgements limit the frames in flight to two, so a slow network
  never builds up a queue of stale frames. Clients without H.264 get planar
  tiles on the graphics pipeline; clients without the pipeline get bitmap
  updates (64×64 changed tiles, planar at 32 bpp).
- Pipeline statistics (fps, encode time, data rate) are logged every 3 s in
  the `performance` log category.
- Keyboard (scancodes and Unicode), mouse buttons, wheel, horizontal wheel,
  extra buttons and double clicks.
- Login types:
  - **macOS user account**: the password is checked with Open Directory. By
    default only the user who owns the shared desktop can log in.
  - **iRdp user name and password**: stored as a salted PBKDF2 hash.
  - **No authentication**: anyone who can reach the port can connect.
- Shared resources: which display to share, the resolution (points, native
  pixels or half), the color depth, the frame rate, whether the keyboard and
  the mouse are shared, and an optional Ctrl/Command swap.
- A self-signed TLS certificate is generated on first start. Its SHA-256
  fingerprint is shown in Settings → General.
- Connections from other computers on the network: with "Other computers on
  the network" (the default) the service listens on all interfaces, IPv4 and
  IPv6. Settings → General lists the addresses to use (Bonjour name such as
  `Mac-Studio.local` and IP addresses) and the state of the macOS firewall.
  "This Mac only" restricts the service to `127.0.0.1`.
- After 5 failed logins within 5 minutes an address is locked out for 5
  minutes.
- A new session replaces the previous one.

- When the client does not send a valid user name and password (for example
  `mstsc` without saved credentials), iRdp shows its own logon screen inside
  the session. Problems such as a missing Screen Recording permission are also
  shown on the screen instead of closing the connection.

Not included by design: clipboard, audio, drives and printers. NLA (CredSSP)
is not supported yet: the server selects TLS.

## Requirements

- macOS 15 or later
- Xcode with Swift 6.4 (built and tested with Xcode 27.2)

## Repository layout

Everything is in `src`, organized like a .NET solution:

| .NET | iRdp |
| --- | --- |
| `.sln` | `src/iRdp.xcworkspace` |
| class library `.csproj` | a Swift package in `src/Packages/<Name>` with its own `Package.swift` |
| executable `.csproj` | `src/App/iRdp.xcodeproj` (targets `iRdp` and `iRdpService`) |
| test project | the package's `Tests/<Name>Tests` folder |

| Package | Purpose |
| --- | --- |
| `RdpProtocol` | Encoding and decoding of RDP PDUs (TPKT, X.224, BER/PER, MCS, GCC, capabilities, share PDUs, fast-path, planar codec) |
| `RdpServer` | SwiftNIO TLS server, connection state machine, tile encoder, certificate generation |
| `IRdpConfiguration` | Settings, login types, shared resources, status files shared by the app and the service |
| `MacIntegration` | ScreenCaptureKit capture, Quartz input injection, scancode map, Open Directory, displays, permissions |
| `IRdpServiceCore` | Service runtime: applies settings, authenticates and reports status |

Dependencies: `RdpServer` → `RdpProtocol`; `MacIntegration` → `RdpServer`,
`IRdpConfiguration`; `IRdpServiceCore` → `MacIntegration`; the app target
`iRdp` → `IRdpConfiguration`, `MacIntegration`; `iRdpService` →
`IRdpServiceCore`. Each type is in its own file.

## Open in Xcode

```bash
open src/iRdp.xcworkspace
```

The `iRdp` scheme builds and runs the menu bar app with iRdpService and the
LaunchAgent embedded in the bundle. Product → Test (⌘U) runs the tests of all
packages. Each package also has its own scheme. The app project is generated
from `src/App/project.yml` with XcodeGen (`cd src/App && xcodegen generate`).

## Build and test from Terminal

```bash
src/Scripts/test-all.sh              # swift test in every package
src/Scripts/build-app.sh             # creates src/.build/app/iRdp.app
src/Scripts/build-app.sh --install   # also copies it to /Applications
```

The tests include an end-to-end test that runs the server on a local port and
drives it through TLS with a test RDP client: it checks the handshake, screen
updates, input, a wrong password, a client without TLS and a session takeover.

## First run

1. Open `/Applications/iRdp.app`. A display icon appears in the menu bar.
2. Choose **Settings…** and pick a login type (Login tab).
3. Choose **Start Service**. When a permission is missing, iRdp opens
   Settings → Permissions at launch. Grant **Screen Recording** and
   **Accessibility** to **iRdp** (they also apply to iRdpService inside the
   app), then use **Restart Service**. The service itself never shows
   permission prompts.
4. In Windows App, add a PC with this Mac's address (Settings → General lists
   the addresses), set a user account with your user name and password, and
   accept the certificate warning on the first connection.

Only the copy in `/Applications` (or `~/Applications`) registers the
LaunchAgent; a development build run from Xcode starts the service as a child
process, so the two never compete for the same agent.

The service can also be controlled from Terminal:

```bash
/Applications/iRdp.app/Contents/MacOS/iRdp --start-service
/Applications/iRdp.app/Contents/MacOS/iRdp --stop-service
/Applications/iRdp.app/Contents/MacOS/iRdp --restart-service
```

The service reads `~/Library/Application Support/iRdp/settings.json` and
writes `status.json` next to it. To see its log:

```bash
log stream --predicate 'subsystem == "com.irdp"' --info
```

For diagnostics, running the service with `IRDP_TEST_PATTERN=1` shares an
animated test pattern instead of the screen.

## License

MIT, see [LICENSE](LICENSE).
