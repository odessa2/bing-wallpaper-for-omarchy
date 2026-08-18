# Bing Wallpaper for Omarchy

A headless Omarchy Quattro plugin that downloads Bing's current regional and
international homepage images, then sets the preferred one as the system
background. It checks immediately when Omarchy Shell starts and every hour
afterward.

The regional image is selected by default. If that request fails, the plugin
falls back to the international image. Downloads are atomic, unchanged images
are reused, and the cache retains the eight most recent images from each feed.

## Requirements

- Omarchy 4 / Quattro
- `curl`, `jq`, `flock`, and `sha256sum` (included in a standard Omarchy install)
- Network access to `www.bing.com`

The plugin runs without elevated privileges. It contacts Bing's homepage image
feed and stores images under `~/.cache/omarchy/bing-wallpaper/`.

## Install

Once this repository has a remote:

```sh
omarchy plugin add https://github.com/OWNER/REPOSITORY.git --enable
```

For local development, clone or copy this folder to
`~/.config/omarchy/plugins/dev.dlg.bing-wallpaper`, then run:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/dev.dlg.bing-wallpaper
omarchy-shell shell rescanPlugins
omarchy plugin enable dev.dlg.bing-wallpaper
```

## Configure

Configuration is optional. Copy `config.example.json` to
`~/.config/omarchy/bing-wallpaper.json`:

```json
{
  "market": "auto",
  "internationalMarket": "en-US",
  "source": "regional"
}
```

- `market`: `auto` uses the desktop locale, or set a Bing market such as
  `de-DE`, `en-GB`, or `ja-JP`.
- `internationalMarket`: the comparison/fallback feed; defaults to `en-US`.
- `source`: which successfully downloaded image to apply, either `regional` or
  `international`.

Changes take effect on the next hourly check. To refresh immediately:

```sh
omarchy-shell bing-wallpaper refresh
```

Inspect the service state with:

```sh
omarchy-shell bing-wallpaper status
```

Image metadata is available in the cache as `regional-current.json` and
`international-current.json`, including Bing's copyright attribution and link.

## Remove

```sh
omarchy plugin remove dev.dlg.bing-wallpaper
rm -r ~/.cache/omarchy/bing-wallpaper ~/.local/state/omarchy/bing-wallpaper
```

The final cleanup command is optional and removes downloaded images and the
plugin's lock file. Omarchy keeps the last selected background until another
background is chosen.

## Data source

The plugin uses Bing's homepage image archive endpoint:
`https://www.bing.com/HPImageArchive.aspx`. Bing owns the images and associated
metadata; this plugin does not grant redistribution rights.
