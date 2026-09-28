# Media

A download stack for watching on the TV and reading manga, adapted from Akita's
[personal Netflix](https://akitaonrails.com/en/2024/04/03/my-personal-netflix-with-docker-compose/)
and [its compose files](https://github.com/akitaonrails/plex_home_server_docker)
for a single Windows PC with no NAS.

- Docker on WSL runs the apps that find and download releases.
- The files live on a Windows drive, `D:\Media` by default.
- Kodi on Windows plays them on the TV over HDMI. Jellyfin is ready for when
  other devices need to stream.
- Suwayomi downloads manga chapters, and Kavita reads them on the PC, a phone,
  or a Kindle after conversion.

## What differs from Akita's setup

Akita splits his server into five compose projects: media, network, utilities,
disc ripping and manga. Media and manga apply here, so it is one
`compose.yml`, and manga and the streaming server are
[profiles](https://docs.docker.com/compose/how-tos/profiles/) you can switch on.
`COMPOSE_PROFILES` in `.env` sets which ones `docker compose up -d` starts.

| Akita | Here | Why |
| --- | --- | --- |
| Synology NAS mounted at `/mnt/terachad` | `D:\Media`, seen as `/mnt/d/Media` | no NAS; WSL writes to NTFS at about 200 MB/s and supports hardlinks |
| Plex | Kodi on Windows; Jellyfin as the `server` profile | the TV is plugged into the PC; Plex charges for hardware transcoding and remote play |
| qBittorrent, Jackett, Prowlarr, FlareSolverr, Radarr, Sonarr, Bazarr, Seerr | the same | |
| SABnzbd | not included | Usenet needs a paid provider |
| Kaizoku | Suwayomi, in the `manga` profile | Kaizoku was archived in 2025 and its sources no longer update; Suwayomi does the same job with Mihon/Tachiyomi extensions |
| Kavita | the same, in the `manga` profile | |
| Lidarr, Navidrome | not included | music was not asked for |
| Portainer, Watchtower, Organizr, Librespeed | not included | `lazydocker` covers Portainer; images are updated by hand |
| Pi-hole, cloudflared, ZeroTier | not included | network infrastructure, not media |
| MakeMKV, HandBrake | not included | no disc drive |
| A daily cleanup script for stuck downloads | the `janitor` service | runs whenever the stack runs, with no cron on the host |

Most of the article is settings made inside the apps, not compose options.
`configure.py` applies them over each app's API; see
[What configure.py sets](#what-configurepy-sets).

## Folders

WSL sees `D:\Media` as `/mnt/d/Media`, and the containers see it as `/data`:

```text
D:\Media
├── torrents\        qBittorrent downloads here, one folder per category
│   ├── movies\
│   └── tv\
├── media\           the library Kodi and Jellyfin read
│   ├── movies\
│   └── tv\
└── manga\
    └── mangas\      Suwayomi's chapters, one CBZ each: <source>\<title>\<chapter>.cbz
```

Downloads and the library share a drive, so Radarr and Sonarr hardlink finished
downloads into the library. A film takes its space once, even while it seeds.

App settings and databases stay on the WSL disk in `~/.local/share/media`.
SQLite databases break easily on `/mnt/c` and `/mnt/d`.

## Start

The Arch installer's `--docker` option sets up Docker. From WSL:

```bash
cd ~/dotfiles/media
cp .env.example .env          # then edit the drive, port and passwords
mkdir -p /mnt/d/Media/{torrents,media}/{movies,tv} /mnt/d/Media/manga/mangas
mkdir -p ~/.local/share/media/{qbittorrent,jackett,prowlarr,radarr,sonarr,bazarr,jellyfin,seerr,suwayomi,kavita}
docker compose up -d
./configure.py
```

Create the settings folders before the first `up`. Otherwise Docker creates
them as root, and Seerr and Suwayomi cannot write to their folders.

`configure.py` asks for a password if `.env` has none. qBittorrent, Radarr,
Sonarr, Prowlarr and Kavita use that password. All of them except Kavita skip
the login when you open them from this PC. The script is safe to rerun. Run it again after adding
films or series so Bazarr gives them a subtitle profile.

Docker starts with WSL, and the containers restart on their own. Docker runs
only while WSL is up, so if downloads pause after you close every terminal,
leave a WSL tab open.

| App | Address | Purpose |
| --- | --- | --- |
| Radarr | http://localhost:7878 | find and download films |
| Sonarr | http://localhost:8989 | find and download series, including new episodes |
| Prowlarr | http://localhost:9696 | the only place indexers are managed |
| qBittorrent | http://localhost:8080 | downloads, plus manual searches in its Search tab |
| Jackett | http://localhost:9117 | indexers for qBittorrent's manual search |
| Bazarr | http://localhost:6767 | subtitles |
| Suwayomi | http://localhost:4567 | find and download manga, including new chapters |
| Kavita | http://localhost:5000 | read manga and serve it to other devices |
| Jellyfin | http://localhost:8096 | optional streaming server |
| Seerr | http://localhost:5055 | optional request and discovery page |

## What configure.py sets

**qBittorrent**
- Blocks these file names at write time: `*.exe *.scr *.bat *.cmd *.msi *.lnk
  *.com *.vbs *.pif`, Akita's list, plus `*.iso *.ps1 *.hta` because the
  files land on Windows. A fake release completes empty, and Radarr or Sonarr
  blocklists it and grabs another.
- Automatic torrent management, `movies` and `tv` categories, and
  `/data/torrents` as the save path.
- Reannounces to trackers when the IP or port changes, and listens on
  `TORRENTING_PORT`.
- Installs the Jackett search plugin with Jackett's API key.

**Radarr and Sonarr**
- A qBittorrent download client with its own category, and the library root folder.
- Minimum sizes, in MB per minute: 720p 3; 1080p 5, Bluray 8, Remux 25; 2160p 10,
  Bluray 15, Remux 50. Each is saved on its own, because bulk saves in the UI
  lose the minimum. Sonarr defaults that are already higher stay as they are.
- A "Known traps" release profile that must not contain `BROADCAST`, `FULL HD`,
  `.scr`, `.exe`, `SODAPOP` or `REACHERSON`.
- Two custom formats scored -500 in every quality profile, so matching releases
  are refused:
  - `foreign-language-only` rejects releases whose audio is none of English,
    Portuguese, Portuguese (Brazil) or the title's original language.
    - Akita matches words like `FRENCH` or `ITALIAN` in the release name.
    - That would reject a French film in its original French.
    - This version uses the apps' language detection, which counts an
      untagged release as the original language.
  - `cyrillic-title` catches releases titled in Cyrillic that carry no Latin
    language marker.
- Kodi metadata files, so Kodi shows artwork and descriptions straight away.

**Prowlarr**
- FlareSolverr as an indexer proxy, used only by indexers tagged `flaresolverr`.
- Radarr and Sonarr as applications, so indexers sync to them.
- The indexers Akita keeps: EZTV and 1337x behind FlareSolverr, YTS, Nyaa and
  AnimeTosho. It tries each mirror in turn, and skips a site that none of them reach.

**Bazarr**
- Connects to Radarr and Sonarr with the same paths they use.
- Turns on the providers tvsubtitles, yifysubtitles, animetosho and gestdown, plus
  OpenSubtitles.com when `.env` has its username and password.
- Adds a "Portuguese (Brazil), then English" profile with the cutoff on
  Portuguese (Brazil). It becomes the default for new items and is assigned to
  existing items that have no profile, because Bazarr silently skips those.
- Ignores embedded PGS subtitles, so Bazarr fetches a text subtitle instead of
  a graphical one that can stutter.

**Kavita**
- Creates the admin account with `MEDIA_USERNAME` and `MEDIA_PASSWORD`.
- Adds a Manga library on Suwayomi's download folder and prints the OPDS
  address for reading apps.

**Suwayomi** is configured through `compose.yml`:
- Chapters are saved as CBZ.
- New chapters download on their own.
- FlareSolverr handles sources behind Cloudflare.
- Auto-download ignores Suwayomi's read status, because reading happens in Kavita.

**Janitor**
- Once a day, removes downloads that have been stuck downloading metadata or
  stalled with no connections for 72 hours, and blocklists them so the apps
  look for another release.
- Slow downloads and items waiting for import are left alone.

## Still by hand

- **Indexers.** Add them only in Prowlarr, never directly in Radarr or Sonarr.
  Fewer good indexers beat many bad ones. Akita turned off LimeTorrents and
  TorrentDownload for serving fakes and malware. Use "Test All Indexers" now
  and then.
- **Quality profile.** When adding a film or series, pick `HD-1080p` or
  `HD - 720p/1080p`. `Any` and `Ultra-HD` will fill the drive quickly.
- **Fakes posted before an episode airs.** Sonarr accepts them. The blocked
  file names usually empty them out, but remove any you notice.
- **Torrents that never start.** Pick another random `TORRENTING_PORT` in `.env`, then run
  `docker compose up -d` and `./configure.py`.

## Read manga

Suwayomi ships without sources. In http://localhost:4567, go to Settings >
Browse > Extension repositories, add the repository you use in Mihon, then
install extensions from Extensions. Search for a title in Browse, add it to
the library, and download its chapters. The library is checked for new
chapters every 12 hours.

Kavita scans the library once a day. To see new chapters sooner, use Scan
Library on the Manga library in http://localhost:5000.

**On the PC**, read in Kavita in the browser. It remembers the page you stopped on.

**On a phone**, use one of these:
- Kavita in the phone's browser; it can be installed as an app from the browser
  menu.
- Any OPDS reader app, with the OPDS address `configure.py` prints. Kavita also
  shows it under your account's settings.
- Mihon on Android, with its Kavita extension; it syncs reading progress.

Either way, the phone must reach the PC:
- **Same Wi-Fi.** Set `networkingMode=mirrored` in `%UserProfile%\.wslconfig`,
  run `wsl --shutdown`, and allow port 5000 in Windows Firewall. Then use
  `http://<PC's IP>:5000`.
- **Away from home.** Install Tailscale on the PC and the phone.
- **Offline.** Copy CBZ files from `D:\Media\manga\mangas` to the phone. Any
  comic reader opens them.

**On a Kindle**, convert chapters first:
- **Why a conversion is needed.** Kindles do not read CBZ, and Kavita's "Send
  to device" only sends EPUB and PDF to a Kindle.
- **Kindle Comic Converter (KCC).** The Windows installer's `-InstallPackages`
  option installs it. Drop chapters or a whole series folder from
  `D:\Media\manga\mangas` into KCC. Pick your Kindle model and MOBI output,
  and turn on "Manga mode" for right-to-left pages.
- **Copying.** Connect the Kindle by USB and drag the MOBI files into its
  `documents` folder. KCC recommends USB over Send to Kindle and Calibre, which
  can break the page layout.

## Watch with Kodi

Kodi is a free media centre app with a full-screen, remote-friendly interface
that reads the library folders directly. The Windows installer's
`-InstallPackages` option installs it. In Kodi:

1. Videos > Files > Add videos: add `D:\Media\media\movies` and set its
   content to Movies, then add `D:\Media\media\tv` as TV shows. Keep the
   default online scraper, or pick "Local information only" to use the
   metadata files Radarr and Sonarr write.
2. Settings > Media > Library: turn on "Update library on startup".

Kodi picks up Bazarr's `.srt` files next to each video.

## Optional streaming server

To watch on a phone, another TV or away from home:

```bash
docker compose --profile server up -d
```

- **Jellyfin.** Open http://localhost:8096 and add `/data/media/movies` and
  `/data/media/tv` as libraries.
- **Seerr.** Open http://localhost:5055, sign in with the Jellyfin account, and
  add Radarr (`radarr:7878`) and Sonarr (`sonarr:8989`) with their API keys,
  found under each app's Settings > General.
- **Other devices.** They reach WSL only with `networkingMode=mirrored` in
  `%UserProfile%\.wslconfig` and a firewall rule for port 8096.
- **Watching away from home.** Tailscale is the free option.
- **Hardware transcoding.** The NVIDIA card needs `nvidia-container-toolkit`
  and the commented `deploy` block in `compose.yml`.

## Maintenance

```bash
docker compose pull && docker compose up -d    # update the images (see below)
docker compose logs -f radarr                  # follow one app's log
docker compose logs janitor                    # what the cleanup removed
docker compose down                            # stop everything
```

Suwayomi's image is published only on GitHub's registry. If `docker compose
pull` fails with `denied` for a `ghcr.io` image, Docker is sending an expired
GitHub login; run `docker logout ghcr.io` and pull again.
