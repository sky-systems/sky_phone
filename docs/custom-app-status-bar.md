# Custom app status-bar contrast

An embedded app can report the opaque background beneath the phone's status bar:

```js
window.parent.postMessage({
  type: 'sky-phone-app:status-bar-background',
  appId: new URLSearchParams(location.search).get('skyPhoneAppId'),
  protocolVersion: 1,
  background: 'rgb(148, 23, 30)',
}, '*')
```

Report the actual top background after mounting and when that background changes.
Phone accepts three/six-digit hex, RGB and opaque RGBA colors and chooses the existing
light or dark status icons by their relative contrast. Transparent colors cannot
identify the underlying background. Send `background: null` to restore the normal
Phone appearance.

Messages are accepted only from that app's own iframe with its matching app ID,
origin and protocol version. Loading/error screens and closing or switching apps
restore Phone's normal status-bar appearance. Apps without this message keep their
existing behavior; no permission, config, SQL or dependency update is needed.
