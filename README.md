# SubsTab

Restores a **Subs** tab to the YouTube iOS bottom tab bar.

YouTube moved Subscriptions into the Home top bar. This tweak inserts a synthetic
`FEsubscriptions` pivot item into the bottom bar. It is an on/off toggle in the
**Tweaks** section of YouTube Settings.

## Building

Requires [Theos](https://theos.dev) and the iOS SDK.

```sh
make clean package DEBUG=0 FINALPACKAGE=1
```

The resulting `.deb` is in `packages/`.

## Installation

- Jailbroken: install the `.deb`.
- Sideloaded IPA: inject `SubsTab.dylib` into the YouTube IPA with your signing tool.

## Notes

- The toggle is in YouTube Settings → Tweaks → Subs Tab.
- Default is on. Changing the toggle calls `refreshPivotBar`; restart YouTube if the tab does not update.
- Requires the `YTIPivotBarRenderer` factory to add the synthetic tab.
