# iRdp

iRdp is a native macOS Remote Desktop Protocol (RDP) server written in Swift.
Connect to the current Mac desktop from an RDP client such as Windows App,
`mstsc.exe`, or FreeRDP. The server shares a selected display and forwards
keyboard and mouse input.

`iRdp.app` is the menu bar app for configuration and service control.
`iRdpService` accepts connections, captures the display with ScreenCaptureKit,
and posts keyboard and mouse events through Core Graphics. One remote session
is active at a time. A new session replaces the previous one.

## Requirements

- macOS 15 or later
- Xcode with Swift 6.4 to build from source
- Screen Recording permission for display capture and Accessibility permission
  for remote input

## Build from source

From the repository root, open the workspace and run the `iRdp` scheme.

```sh
open src/iRdp.xcworkspace
```

If Xcode reports a signing error, select your development team for both app
targets, `iRdp` and `iRdpService`. The workspace uses the checked-in Xcode
project. If you change `src/App/project.yml`, regenerate it with
`(cd src/App && xcodegen generate)`.

The build script writes the signed bundle to `src/.build/app/iRdp.app`.

```sh
./src/Scripts/build-app.sh
```

Run `./src/Scripts/build-app.sh --install` to install the bundle in
`/Applications`. This replaces any existing iRdp installation there.
Copies installed in `/Applications` or `~/Applications` run the service as a
LaunchAgent. Development builds run it as a child process.

## Connect

1. Open iRdp from the menu bar and go to **Settings → Login**. Select a local
   macOS account or create an iRdp account. With a macOS account and Network
   Level Authentication (NLA) enabled, enter the account password and click
   **Save RDP Password**.
2. Grant iRdp **Screen Recording** and **Accessibility** in macOS System
   Settings. Use **Start Service** in iRdp, or **Restart Service** if it was
   already running when you granted permissions.
3. In your RDP client, add a PC using one of the addresses shown under
   **Settings → General**. The default port is TCP 3389. Use the credentials
   configured in step 1. iRdp generates a self-signed TLS certificate on first
   start. Check its fingerprint in **General** before trusting it.

**Shared Resources** controls which display to capture, its resolution and
frame rate, and whether remote keyboard and mouse input are enabled.
Connections use TLS, with CredSSP/NTLM when NLA is enabled. The graphics
pipeline uses H.264 (AVC420) when hardware encoding is enabled and the client
advertises support. Other clients receive planar graphics or bitmap updates,
depending on their capabilities. Clipboard, audio, drive, and printer
redirection are outside the scope of the project.

## Project layout

| Path under `src/` | Responsibility |
| --- | --- |
| `App/` | SwiftUI menu bar app and the service executable |
| `Packages/RdpProtocol/` | RDP packet encoding, decoding, and framing |
| `Packages/RdpServer/` | SwiftNIO server, TLS, authentication, session handling, and frame encoding |
| `Packages/IRdpConfiguration/` | Settings and status shared by the app and service |
| `Packages/MacIntegration/` | Screen capture, input injection, displays, permissions, and account validation |
| `Packages/IRdpServiceCore/` | Service runtime that wires the server to macOS |

Run all package tests from the terminal, or use **Product → Test** with the
`iRdp` scheme in Xcode.

```sh
./src/Scripts/test-all.sh
```

## Diagnostics

Stream the iRdp logs while opening a connection.

```sh
log stream --info --predicate 'subsystem == "com.irdp"'
```

For a blank screen, look for capture errors in `capture`, the negotiated
graphics mode in `connection`, and frame timings in `performance`. The
performance timings describe capture, encoding, and sending on the server.
If the service process starts with `IRDP_TEST_PATTERN=1`, it sends an animated
test pattern in place of the captured desktop.

The app and service use `~/Library/Application Support/iRdp/` for
`settings.json`, `status.json`, and TLS certificate files.

## License

[MIT](LICENSE)
