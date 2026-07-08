# macOS permissions and rebuilds

Field75 Mapper needs two different macOS privacy grants depending on what you use:

- **Input Monitoring**: needed when the GUI app cannot see the Field75 HID control interface but `field75ctl list` can.
- **Accessibility**: needed only for Mac Macro mode, because the app listens for F13-F20 carrier keys and runs local actions.

## The rule

Always grant permissions to:

```text
/Applications/Field75Mapper.app
```

Do not grant permissions to `dist/Field75Mapper.app` unless you are explicitly testing a one-off development build. `dist` is rebuilt constantly and is not a stable app identity.

## Why permissions keep breaking

macOS TCC permissions are tied to the app's identity. In practice that means the path, bundle identifier, and code signing requirement all matter.

Field75 Mapper's stable bundle identifier is:

```text
dev.samanthamyers.Field75Mapper
```

The build script installs to:

```text
/Applications/Field75Mapper.app
```

That keeps the path and bundle identifier stable. For the signing requirement to stay stable across rebuilds, use a persistent signing identity instead of ad-hoc signing.

## Recommended local build command

First check available signing identities:

```sh
security find-identity -v -p codesigning
```

Then build and install with a stable identity:

```sh
FIELD75_CODESIGN_IDENTITY="Field75Mapper Local" ./script/build_and_run.sh --verify
```

You can also use an Apple Development or Developer ID Application identity if one is available:

```sh
FIELD75_CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./script/build_and_run.sh --verify
```

If `FIELD75_CODESIGN_IDENTITY` is not set, the script uses ad-hoc signing (`-`). That works for launching the app, but it can invalidate Input Monitoring or Accessibility grants after rebuilds because the signing requirement can change.

## Creating a local signing identity

Use Keychain Access:

1. Open Keychain Access.
2. Choose Certificate Assistant > Create a Certificate.
3. Name it `Field75Mapper Local`.
4. Use a self-signed certificate suitable for code signing.
5. Confirm it appears in:

```sh
security find-identity -v -p codesigning
```

Then always build with:

```sh
FIELD75_CODESIGN_IDENTITY="Field75Mapper Local" ./script/build_and_run.sh --verify
```

## If permissions are already broken

1. Quit Field75 Mapper.
2. Build and install with the stable identity.
3. Open System Settings > Privacy & Security > Input Monitoring.
4. Remove stale Field75Mapper entries that point to older builds.
5. Add `/Applications/Field75Mapper.app`.
6. Repeat for Accessibility only if using Mac Macro mode.
7. Relaunch Field75 Mapper.

Do not reset all TCC permissions unless the system entry is badly wedged; it is usually enough to remove stale app entries and add the installed app once.
