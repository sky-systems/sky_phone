# sky_phone

FiveM phone scaffold for Sky-Systems, using Vue 3 and Konsta UI.

## Development

```powershell
cd frontend
pnpm install
pnpm dev
```

The development command starts Vite and a small mock server for NUI callbacks. The phone opens
automatically in browser development mode.

## Build

```powershell
cd frontend
pnpm build
```

The production build is published to `sky_phone/source/html/`. In FiveM, ensure `sky_base` before
`sky_phone` and use `/phone` to toggle the UI.

