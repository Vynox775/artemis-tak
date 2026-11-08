<div align="center">

<img src="images/op-silent-talon.webp" alt="Op Silent Talon: an example plan drawn in RO-TAK" width="100%">

# RO-TAK

**Real-time shared map annotation for games.** Upload a map, draw, drop military symbols and waypoints, measure bearings and share a room link.

<p>
<a href="https://github.com/rice-evans/RO-TAK"><img src="https://img.shields.io/github/stars/rice-evans/RO-TAK?style=flat&logo=github" alt="Stars"></a>
<a href="https://github.com/rice-evans/RO-TAK/blob/main/LICENSE"><img src="https://img.shields.io/github/license/rice-evans/RO-TAK?style=flat" alt="License"></a>
<a href="https://github.com/rice-evans/RO-TAK/commits/main"><img src="https://img.shields.io/github/last-commit/rice-evans/RO-TAK?style=flat" alt="Last commit"></a>
<a href="https://github.com/rice-evans/RO-TAK/releases/latest"><img src="https://img.shields.io/github/v/release/rice-evans/RO-TAK?style=flat" alt="Release"></a>
<a href="https://github.com/rice-evans/RO-TAK/releases"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fro-tak.vercel.app%2Fapi%2Fdownloads&style=flat" alt="Downloads"></a>
<img src="https://img.shields.io/badge/JavaScript-f7df1e?style=flat&logo=javascript&logoColor=black" alt="JavaScript">
<img src="https://img.shields.io/badge/Electron-47848f?style=flat&logo=electron&logoColor=white" alt="Electron">
</p>

<p>
<a href="https://ro-tak.vercel.app"><img src="https://img.shields.io/badge/WEB_APP-RO--TAK.VERCEL.APP-3b82f6?style=for-the-badge&labelColor=444444" alt="Web app"></a>
</p>

<p>
<a href="https://github.com/rice-evans/RO-TAK/releases/latest"><img src="https://img.shields.io/badge/DOWNLOAD-WINDOWS_%28.EXE%29-3b82f6?style=for-the-badge&labelColor=444444" alt="Download for Windows"></a>
<a href="https://github.com/rice-evans/RO-TAK/releases/latest"><img src="https://img.shields.io/badge/DOWNLOAD-MACOS_APPLE_SILICON-000000?style=for-the-badge&labelColor=444444&logo=apple&logoColor=white" alt="Download for macOS Apple Silicon"></a>
<a href="https://github.com/rice-evans/RO-TAK/releases/latest"><img src="https://img.shields.io/badge/DOWNLOAD-MACOS_INTEL-1f1f1f?style=for-the-badge&labelColor=444444&logo=apple&logoColor=white" alt="Download for macOS Intel"></a>
</p>

<p>
<a href="https://github.com/rice-evans/RO-TAK/releases">Releases</a> · <a href="https://github.com/rice-evans/RO-TAK/blob/main/SECURITY.md">Security</a> · <a href="https://github.com/rice-evans/RO-TAK/blob/main/LICENSE">License</a>
</p>

<p>If you enjoy RO-TAK, be sure to star the GitHub repository, and post photos in respective Discord servers and @ me!</p>

</div>

## What it does and does not do

- Runs on its own. It does not read, inject into or modify any game.
- No accounts and no analytics.
- Rooms sync through Supabase and are deleted after 24 hours with nobody connected.
- Rooms are not private. Anyone can read a room's map and marks, so do not put anything secret in one.
- Uploaded maps are checked with OpenAI's moderation endpoint before they are stored.

## Layout

- `index.html` - the whole app. The website and the Electron overlay load the same file.
- `desktop/` - Electron wrapper.
- `supabase/` - SQL and the `upload-map` edge function.
- `.github/` - builds the installers on GitHub Actions from this source.

## Run your own copy

1. Create a Supabase project and run `supabase/moderation.sql`, then `supabase/host.sql`.
2. Create a public storage bucket named `maps`.
3. Deploy `supabase/functions/upload-map` with JWT verification off and an `OPENAI_API_KEY` secret.
4. Put your project URL and publishable key in `index.html` (`SUPABASE_URL`, `SUPABASE_KEY`).
5. Host the folder on any static host. `vercel.json` rewrites `/play` to `index.html`.

## Verify a download

Installers are built by GitHub Actions from this repo and carry a signed build attestation.

```
gh attestation verify RO-TAK-Setup-x.y.z.exe --repo rice-evans/RO-TAK
```

Each release also has `SHA256SUMS-Windows.txt` and `SHA256SUMS-macOS.txt`. Compare with `Get-FileHash <file>` on Windows or `shasum -a 256 <file>` on macOS.

## License

MIT, see `LICENSE`. The landing page photos belong to their credited owners and are not covered by it.
Third party: milsymbol (MIT), supabase-js (MIT), IBM Plex Sans (SIL OFL).
