## 0.1.0

- Initial release.
- Zero wiring: `LogibbleInterceptor()` and `LogibbleOverlay()` share `Logibble.instance` by default, so the network layer and the app root stay decoupled. Pass your own `Logibble` for dependency injection.
- Draggable debug bubble that snaps to the screen edge and shows a dot while a request is in flight or failing.
- Network inspector for Dio: filter, status badges, timings, cache hits, full headers and bodies, copy as cURL.
- Storage inspector with pluggable `DebugStorage` sources (secure storage, shared preferences, in-memory caches…).
- Header redaction and a hard `enabled` switch that defaults to `kDebugMode`.
