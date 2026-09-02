# DB-Pickaxe

> **A Windows desktop browser with a built-in media sniffer and downloader.**

DB-Pickaxe embeds a full WebView2 browser and automatically detects downloadable media on any webpage — videos, images, HLS/DASH streams, and audio files. Captured media appears in the resizable side panel ready to download with one click.

---

## Features

- **Browser** — Multi-tab WebView2 browser with history, bookmarks, and cookie management
- **Media Sniffer** — Detects video, image, audio, HLS/DASH streams from page DOM, XHR, fetch, and blob hooks
- **Download Manager** — Concurrent downloads with retry, speed limit, and auto-categorisation
- **Cookie Vault** — Inject custom cookies into the browser session for authenticated downloads
- **Image Converter** — Convert downloaded images to JPG, PNG, or WebP
- **HLS/DASH Streams** — FFmpeg-powered stream downloading
- **Proxy Support** — HTTP proxy with authentication

## Requirements

- **Windows 10/11** (64-bit)
- **Microsoft Edge WebView2 Runtime** — [Download here](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)
- Flutter SDK ^3.13.2

## Getting Started

```bash
flutter pub get
flutter run -d windows
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter (Windows desktop) |
| State Management | Riverpod 2.x |
| Browser Engine | WebView2 (`webview_windows`) |
| Local Storage | Hive |
| HTTP Client | Dio |
| Image Processing | `image` package |
| Stream Download | FFmpeg (via process) |

## Project Structure

```
lib/
  core/           # Shared infrastructure (network, storage, theme, utils)
  features/
    browser/      # Multi-tab browser (tabs, bookmarks, history, cookies)
    downloader/   # Download queue, FFmpeg stream service, image converter
    settings/     # App settings
    sniffer/      # JS payload, media detection, filter/sort
  platform/
    windows/      # Windows-specific initialisation (WebView2, window manager)
```
