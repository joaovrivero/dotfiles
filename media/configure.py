#!/usr/bin/env python3
"""Apply the settings from Akita's "personal Netflix" article to the media stack.

Run it after `docker compose up -d`. It talks to each app over its API, only
adds or updates what it manages, and is safe to rerun: run it again after
adding films or series so Bazarr gives them a language profile.
"""

import getpass
import http.cookiejar
import json
import os
import re
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ENV_FILE = HERE / ".env"

# qBittorrent refuses to write these, so a release that hides malware behind a
# clean name completes empty and Radarr or Sonarr blocklist it.
BLOCKED_FILES = ["*.exe", "*.scr", "*.bat", "*.cmd", "*.msi", "*.lnk", "*.com", "*.vbs", "*.pif",
                 # Additions for a Windows library that never wants disc images or scripts.
                 "*.iso", "*.ps1", "*.hta"]

# Release names known to carry malware or unimportable packs.
MUST_NOT_CONTAIN = ["BROADCAST", "FULL HD", ".scr", ".exe", "SODAPOP", "REACHERSON"]

# Minimum megabytes per minute of video. Zero lets a tiny fake "4K" through.
QUALITY_FLOORS = {
    "HDTV-720p": 3, "WEBDL-720p": 3, "WEBRip-720p": 3, "Bluray-720p": 3,
    "HDTV-1080p": 5, "WEBDL-1080p": 5, "WEBRip-1080p": 5, "Bluray-1080p": 8,
    "Remux-1080p": 25, "Bluray-1080p Remux": 25,
    "HDTV-2160p": 10, "WEBDL-2160p": 10, "WEBRip-2160p": 10, "Bluray-2160p": 15,
    "Remux-2160p": 50, "Bluray-2160p Remux": 50,
}

# Audio languages a release must include at least one of; anything else is a
# foreign dub. "Original" is the film's or series' own language.
WANTED_AUDIO = ["English", "Portuguese", "Portuguese (Brazil)", "Original"]
REJECT_SCORE = -500

# Prowlarr indexers from the article, and whether they sit behind Cloudflare.
INDEXERS = [
    {"definition": "eztv", "flaresolverr": True},
    {"definition": "1337x", "flaresolverr": True},
    {"definition": "yts", "flaresolverr": False},
    {"definition": "nyaasi", "flaresolverr": False},
    {"name": "AnimeTosho", "implementation": "Torznab", "flaresolverr": False},
]

SUBTITLE_PROVIDERS = ["tvsubtitles", "yifysubtitles", "animetosho", "gestdown"]
SUBTITLE_PROFILE = "Portuguese (Brazil), then English"

JACKETT_PLUGIN = "https://raw.githubusercontent.com/qbittorrent/search-plugins/master/nova3/engines/jackett.py"


def step(message):
    print(f"\n\033[1;34m==>\033[0m {message}")


def note(message):
    print(f"  {message}")


def fail(message):
    print(f"\033[1;31merror:\033[0m {message}", file=sys.stderr)
    sys.exit(1)


def load_env():
    env = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip().strip("'\"")
    return {**env, **os.environ}


def save_env(key, value):
    lines = ENV_FILE.read_text().splitlines() if ENV_FILE.exists() else []
    lines = [line for line in lines if not line.startswith(f"{key}=")]
    lines.append(f"{key}={value}")
    ENV_FILE.write_text("\n".join(lines) + "\n")
    ENV_FILE.chmod(0o600)


class Api:
    def __init__(self, base, headers=None):
        self.base = base
        self.headers = headers or {}
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def request(self, method, path, body=None, form=None):
        headers = dict(self.headers)
        data = None
        if form is not None:
            data = urllib.parse.urlencode(form, doseq=True).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        elif body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=120) as response:
                raw = response.read().decode()
        except urllib.error.HTTPError as error:
            detail = error.read().decode()[:500]
            raise RuntimeError(f"{method} {path} returned {error.code}: {detail}") from None
        if not raw:
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw

    def get(self, path):
        return self.request("GET", path)

    def post(self, path, body=None, form=None):
        return self.request("POST", path, body, form)

    def put(self, path, body):
        return self.request("PUT", path, body)


def wait_for(url, name, timeout=180):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(url, timeout=5)
            return
        except urllib.error.HTTPError:
            return  # Any HTTP answer means the app is up, even 401 or 403.
        except (urllib.error.URLError, ConnectionError, TimeoutError):
            time.sleep(2)
    fail(f"{name} did not answer at {url}. Is `docker compose up -d` running?")


def wait_for_file(path, name, timeout=180):
    deadline = time.time() + timeout
    while not path.exists():
        if time.time() > deadline:
            fail(f"{name} has not created {path} yet.")
        time.sleep(2)


def xml_api_key(path):
    return ET.parse(path).getroot().findtext("ApiKey")


def set_fields(resource, values):
    for field in resource["fields"]:
        if field["name"] in values:
            field["value"] = values[field["name"]]
    return resource


def upsert(api, path, existing, body):
    if existing:
        body["id"] = existing["id"]
        return api.put(f"{path}/{existing['id']}", body)
    return api.post(path, body)


def configure_qbittorrent(username, password, port):
    step("qBittorrent")
    wait_for("http://localhost:8080", "qBittorrent")
    api = Api("http://localhost:8080")

    def login(pw):
        try:
            # Older versions answer "Ok." or "Fails."; newer ones 204 or 401.
            return api.post("/api/v2/auth/login", form={"username": username, "password": pw}) != "Fails."
        except RuntimeError:
            return False

    if not login(password):
        logs = subprocess.run(["docker", "compose", "logs", "qbittorrent"], cwd=HERE,
                              capture_output=True, text=True).stdout
        temporary = re.findall(r"temporary password is provided for this session: (\S+)", logs)
        if not (temporary and login(temporary[-1])):
            fail("could not log in to qBittorrent with MEDIA_PASSWORD or the temporary password in its logs.")
        note("replaced the temporary WebUI password")

    api.post("/api/v2/app/setPreferences", form={"json": json.dumps({
        "web_ui_username": username,
        "web_ui_password": password,
        "listen_port": port,
        "random_port": False,
        "upnp": False,
        "reannounce_when_address_changed": True,
        "auto_tmm_enabled": True,
        "torrent_changed_tmm_enabled": True,
        "save_path_changed_tmm_enabled": True,
        "category_changed_tmm_enabled": True,
        "save_path": "/data/torrents",
        "temp_path_enabled": False,
        "excluded_file_names_enabled": True,
        "excluded_file_names": "\n".join(BLOCKED_FILES),
    })})
    note(f"automatic torrent management, reannounce on port change, listening port {port}")
    note("blocked file names: " + " ".join(BLOCKED_FILES))

    categories = api.get("/api/v2/torrents/categories") or {}
    for category in ("movies", "tv"):
        action = "editCategory" if category in categories else "createCategory"
        api.post(f"/api/v2/torrents/{action}", form={"category": category, "savePath": f"/data/torrents/{category}"})
    note("categories movies and tv under /data/torrents")
    return api


def configure_jackett(config_root, qbittorrent):
    step("Jackett")
    server_config = config_root / "jackett/Jackett/ServerConfig.json"
    wait_for_file(server_config, "Jackett")
    config = json.loads(server_config.read_text())
    if config.get("FlareSolverrUrl") != "http://flaresolverr:8191":
        config["FlareSolverrUrl"] = "http://flaresolverr:8191"
        server_config.write_text(json.dumps(config, indent=2))
        subprocess.run(["docker", "compose", "restart", "jackett"], cwd=HERE, check=True, capture_output=True)
    note("FlareSolverr at http://flaresolverr:8191")

    plugins = qbittorrent.get("/api/v2/search/plugins") or []
    if not any(plugin["name"] == "jackett" for plugin in plugins):
        qbittorrent.post("/api/v2/search/installPlugin", form={"sources": JACKETT_PLUGIN})
    plugin = None
    for _ in range(30):
        plugin = next(config_root.joinpath("qbittorrent").glob("**/nova3/engines/jackett.py"), None)
        if plugin:
            break
        time.sleep(1)
    if not plugin:
        fail("qBittorrent did not install the Jackett search plugin.")
    plugin.with_suffix(".json").write_text(json.dumps({
        "api_key": config["APIKey"],
        "url": "http://jackett:9117",
        "tracker_first": False,
        "thread_count": 20,
    }, indent=4))
    note("qBittorrent search plugin pointed at Jackett")


def configure_auth(api, version, username, password):
    host = api.get(f"/api/{version}/config/host")
    host.update({
        "authenticationMethod": "forms",
        "authenticationRequired": "disabledForLocalAddresses",
        "username": username,
        "password": password,
        "passwordConfirmation": password,
    })
    api.put(f"/api/{version}/config/host/{host['id']}", host)


class Arr:
    def __init__(self, name, port, config_root, category, root, category_field):
        self.name = name
        self.port = port
        self.url = f"http://localhost:{port}"
        self.key_file = config_root / name.lower() / "config.xml"
        self.category = category
        self.root = root
        self.category_field = category_field

    def connect(self):
        wait_for(f"{self.url}/ping", self.name)
        wait_for_file(self.key_file, self.name)
        self.key = xml_api_key(self.key_file)
        self.api = Api(self.url, {"X-Api-Key": self.key})
        return self


def configure_arr(arr, username, password):
    step(arr.name)
    api = arr.api
    configure_auth(api, "v3", username, password)
    note("login required except from local addresses")

    if not any(folder["path"] == arr.root for folder in api.get("/api/v3/rootfolder")):
        api.post("/api/v3/rootfolder", {"path": arr.root})
    note(f"root folder {arr.root}")

    schema = next(s for s in api.get("/api/v3/downloadclient/schema") if s["implementation"] == "QBittorrent")
    existing = next((c for c in api.get("/api/v3/downloadclient") if c["implementation"] == "QBittorrent"), None)
    client = set_fields(existing or schema, {
        "host": "qbittorrent", "port": 8080, "username": username, "password": password,
        arr.category_field: arr.category,
    })
    client.update({"name": "qBittorrent", "enable": True})
    if existing:
        api.put(f"/api/v3/downloadclient/{existing['id']}?forceSave=true", client)
    else:
        api.post("/api/v3/downloadclient?forceSave=true", client)
    note(f"download client qBittorrent, category {arr.category}")

    for definition in api.get("/api/v3/qualitydefinition"):
        floor = QUALITY_FLOORS.get(definition["title"])
        if floor is None or (definition.get("minSize") or 0) >= floor:
            continue
        definition["minSize"] = floor
        if definition.get("preferredSize") is not None and definition["preferredSize"] < floor:
            definition["preferredSize"] = floor
        if definition.get("maxSize") is not None and definition["maxSize"] < floor:
            definition["maxSize"] = floor
        # Saved one at a time: bulk saves in the UI do not keep the minimum.
        api.put(f"/api/v3/qualitydefinition/{definition['id']}", definition)
    note("minimum sizes per quality, in MB per minute")

    name = "Known traps"
    existing = next((p for p in api.get("/api/v3/releaseprofile") if p.get("name") == name), None)
    profile = existing or {"name": name, "enabled": True, "required": [], "indexerId": 0, "tags": []}
    profile.update({"enabled": True, "ignored": MUST_NOT_CONTAIN})
    upsert(api, "/api/v3/releaseprofile", existing, profile)
    note("release profile 'Known traps' must not contain: " + ", ".join(MUST_NOT_CONTAIN))

    languages = {language["name"]: language["id"] for language in api.get("/api/v3/language")}
    formats = {
        "foreign-language-only": [
            {"name": f"Not {language}", "implementation": "LanguageSpecification", "negate": True, "required": True,
             "fields": [{"name": "value", "value": languages[language]}, {"name": "exceptLanguage", "value": False}]}
            for language in WANTED_AUDIO
        ],
        # Releases titled entirely in Cyrillic carry no Latin language marker.
        "cyrillic-title": [
            {"name": "Cyrillic", "implementation": "ReleaseTitleSpecification", "negate": False, "required": True,
             "fields": [{"name": "value", "value": r"\p{IsCyrillic}"}]}
        ],
    }
    current = {f["name"]: f for f in api.get("/api/v3/customformat")}
    format_ids = []
    for format_name, specifications in formats.items():
        body = {"name": format_name, "includeCustomFormatWhenRenaming": False, "specifications": specifications}
        saved = upsert(api, "/api/v3/customformat", current.get(format_name), body)
        format_ids.append(saved["id"])
    for quality_profile in api.get("/api/v3/qualityprofile"):
        for item in quality_profile["formatItems"]:
            if item["format"] in format_ids:
                item["score"] = REJECT_SCORE
        api.put(f"/api/v3/qualityprofile/{quality_profile['id']}", quality_profile)
    note(f"custom formats foreign-language-only and cyrillic-title score {REJECT_SCORE} in every quality profile")

    metadata = next(m for m in api.get("/api/v3/metadata") if m["implementation"] == "XbmcMetadata")
    metadata["enable"] = True
    api.put(f"/api/v3/metadata/{metadata['id']}", metadata)
    note("Kodi metadata files next to each video")


def configure_prowlarr(config_root, arrs, username, password):
    step("Prowlarr")
    key_file = config_root / "prowlarr/config.xml"
    wait_for("http://localhost:9696/ping", "Prowlarr")
    wait_for_file(key_file, "Prowlarr")
    api = Api("http://localhost:9696", {"X-Api-Key": xml_api_key(key_file)})
    configure_auth(api, "v1", username, password)
    note("login required except from local addresses")

    tag = next((t for t in api.get("/api/v1/tag") if t["label"] == "flaresolverr"), None)
    tag = tag or api.post("/api/v1/tag", {"label": "flaresolverr"})
    existing = next((p for p in api.get("/api/v1/indexerProxy") if p["implementation"] == "FlareSolverr"), None)
    schema = next(s for s in api.get("/api/v1/indexerProxy/schema") if s["implementation"] == "FlareSolverr")
    proxy = set_fields(existing or schema, {"host": "http://flaresolverr:8191/"})
    proxy.update({"name": "FlareSolverr", "tags": [tag["id"]]})
    upsert(api, "/api/v1/indexerProxy", existing, proxy)
    note("FlareSolverr proxy for indexers tagged flaresolverr")

    schema = next(s for s in api.get("/api/v1/downloadclient/schema") if s["implementation"] == "QBittorrent")
    existing = next((c for c in api.get("/api/v1/downloadclient") if c["implementation"] == "QBittorrent"), None)
    client = set_fields(existing or schema, {"host": "qbittorrent", "port": 8080, "username": username, "password": password})
    client.update({"name": "qBittorrent", "enable": True})
    if existing:
        api.put(f"/api/v1/downloadclient/{existing['id']}?forceSave=true", client)
    else:
        api.post("/api/v1/downloadclient?forceSave=true", client)
    note("download client qBittorrent")

    applications = api.get("/api/v1/applications")
    schemas = api.get("/api/v1/applications/schema")
    for arr in arrs:
        existing = next((a for a in applications if a["implementation"] == arr.name), None)
        app = set_fields(existing or next(s for s in schemas if s["implementation"] == arr.name), {
            "prowlarrUrl": "http://prowlarr:9696",
            "baseUrl": f"http://{arr.name.lower()}:{arr.port}",
            "apiKey": arr.key,
        })
        app.update({"name": arr.name, "syncLevel": "fullSync"})
        upsert(api, "/api/v1/applications", existing, app)
    note("syncs indexers to " + " and ".join(arr.name for arr in arrs))

    indexers = api.get("/api/v1/indexer")
    schemas = api.get("/api/v1/indexer/schema")
    for wanted in INDEXERS:
        if "definition" in wanted:
            match = lambda i, w=wanted: i.get("definitionName") == w["definition"]
        else:
            match = lambda i, w=wanted: i["implementation"] == w["implementation"] and i["name"] == w["name"]
        if any(match(i) for i in indexers):
            continue
        indexer = next(s for s in schemas if match(s))
        indexer.update({"enable": True, "appProfileId": 1, "priority": 25,
                        "tags": [tag["id"]] if wanted["flaresolverr"] else []})
        # Sites move between mirrors and some are blocked by DNS, so try each one.
        error = None
        for url in indexer.get("indexerUrls") or [None]:
            if url:
                set_fields(indexer, {"baseUrl": url})
            try:
                api.post("/api/v1/indexer?forceSave=true", indexer)
                note(f"added indexer {indexer['name']} ({url or 'default address'})")
                break
            except RuntimeError as exc:
                error = exc
        else:
            reason = re.search(r'"detailedDescription": "([^"]*)"', str(error))
            note(f"skipped indexer {indexer['name']}: no mirror answered ({reason.group(1) if reason else error})")
    api.post("/api/v1/command", {"name": "ApplicationIndexerSync"})
    names = [i["name"] for i in api.get("/api/v1/indexer")]
    note("indexers synced to the apps: " + (", ".join(names) or "none"))


def configure_bazarr(config_root, arrs, env):
    step("Bazarr")
    config_file = config_root / "bazarr/config/config.yaml"
    wait_for("http://localhost:6767", "Bazarr")
    wait_for_file(config_file, "Bazarr")
    key = re.search(r"^auth:\n(?:\s+.*\n)*?\s+apikey: (\S+)", config_file.read_text(), re.M).group(1)
    api = Api("http://localhost:6767", {"X-API-KEY": key})

    providers = list(SUBTITLE_PROVIDERS)
    form = {"languages-enabled": ["pb", "en"]}
    for arr in arrs:
        section = arr.name.lower()
        form.update({
            f"settings-general-use_{section}": "true",
            f"settings-{section}-ip": section,
            f"settings-{section}-port": str(arr.port),
            f"settings-{section}-base_url": "/",
            f"settings-{section}-apikey": arr.key,
        })
    if env.get("OPENSUBTITLES_USERNAME") and env.get("OPENSUBTITLES_PASSWORD"):
        # The provider wants the username; an email address locks you out for 12 hours.
        providers.insert(0, "opensubtitlescom")
        form["settings-opensubtitlescom-username"] = env["OPENSUBTITLES_USERNAME"]
        form["settings-opensubtitlescom-password"] = env["OPENSUBTITLES_PASSWORD"]
    form["settings-general-enabled_providers"] = providers
    # Graphical PGS tracks stutter; look for a text subtitle even when one exists.
    form["settings-general-ignore_pgs_subs"] = "true"

    profiles = api.get("/api/system/languages/profiles") or []
    ours = next((p for p in profiles if p["name"] == SUBTITLE_PROFILE), None)
    profile_id = ours["profileId"] if ours else max([p["profileId"] for p in profiles], default=0) + 1
    no = {"audio_exclude": "False", "audio_only_include": "False", "hi": "False", "forced": "False"}
    profile = {
        "profileId": profile_id, "name": SUBTITLE_PROFILE, "cutoff": 1,
        "items": [{"id": 1, "language": "pb", **no}, {"id": 2, "language": "en", **no}],
        "mustContain": [], "mustNotContain": [], "originalFormat": False, "tag": None,
    }
    form["languages-profiles"] = json.dumps([p for p in profiles if p["profileId"] != profile_id] + [profile])
    form.update({
        "settings-general-serie_default_enabled": "true",
        "settings-general-serie_default_profile": str(profile_id),
        "settings-general-movie_default_enabled": "true",
        "settings-general-movie_default_profile": str(profile_id),
    })
    api.post("/api/system/settings", form=form)
    note("connected to " + " and ".join(arr.name for arr in arrs))
    note("providers: " + ", ".join(providers))
    if "opensubtitlescom" not in providers:
        note("set OPENSUBTITLES_USERNAME and OPENSUBTITLES_PASSWORD in .env to add OpenSubtitles.com")
    note(f"default profile '{SUBTITLE_PROFILE}', cutoff on Portuguese (Brazil)")

    # Bazarr silently skips anything without a profile, and the default only
    # covers items added later.
    assigned = 0
    for kind, id_field in (("series", "sonarrSeriesId"), ("movies", "radarrId")):
        items = (api.get(f"/api/{kind}?length=-1") or {}).get("data", [])
        missing = [item[id_field] for item in items if item.get("profileId") is None]
        if missing:
            key_name = "seriesid" if kind == "series" else "radarrid"
            api.post(f"/api/{kind}", form={key_name: missing, "profileid": [str(profile_id)] * len(missing)})
            assigned += len(missing)
    note(f"assigned the profile to {assigned} item(s) that had none")


def configure_kavita(username, password):
    step("Kavita")
    wait_for("http://localhost:5000", "Kavita")
    api = Api("http://localhost:5000")
    account = {"username": username, "password": password, "email": ""}
    try:
        api.post("/api/account/register", account)  # The first account becomes the admin.
        note(f"created the admin account {username}")
    except RuntimeError:
        pass  # Already set up.
    try:
        login = api.post("/api/account/login", account)
    except RuntimeError:
        fail(f"could not log in to Kavita as {username}; was the account created with another password?")
    api.headers["Authorization"] = f"Bearer {login['token']}"

    folder = "/data/manga/mangas"
    if not any(folder in library["folders"] for library in api.get("/api/library/libraries")):
        api.post("/api/library/create", {
            "id": 0, "name": "Manga", "type": 0, "folders": [folder],
            "folderWatching": False, "includeInDashboard": True, "includeInSearch": True,
            "manageCollections": True, "manageReadingLists": True, "allowScrobbling": False,
            "allowMetadataMatching": False, "enableMetadata": True, "removePrefixForSortName": False,
            "inheritWebLinksFromFirstChapter": False, "metadataProvider": 3,
            "fileGroupTypes": [1, 2, 3, 4], "excludePatterns": [],
        })
    note(f"Manga library on {folder}, where Suwayomi saves chapters")
    note(f"OPDS feed for reading apps: http://<this PC>:5000/api/opds/{login['apiKey']}")


def main():
    env = load_env()
    config_root = Path(os.path.expanduser(env.get("CONFIG_ROOT") or "~/.local/share/media"))
    username = env.get("MEDIA_USERNAME") or "admin"
    password = env.get("MEDIA_PASSWORD")
    if not password:
        password = getpass.getpass("Password for qBittorrent, Radarr, Sonarr, Prowlarr and Kavita (empty generates one): ")
        password = password or secrets.token_urlsafe(18)
        save_env("MEDIA_PASSWORD", password)
        print(f"Saved MEDIA_PASSWORD to {ENV_FILE}")
    port = int(env.get("TORRENTING_PORT") or 52817)

    qbittorrent = configure_qbittorrent(username, password, port)
    configure_jackett(config_root, qbittorrent)
    radarr = Arr("Radarr", 7878, config_root, "movies", "/data/media/movies", "movieCategory").connect()
    sonarr = Arr("Sonarr", 8989, config_root, "tv", "/data/media/tv", "tvCategory").connect()
    for arr in (radarr, sonarr):
        configure_arr(arr, username, password)
    configure_prowlarr(config_root, [radarr, sonarr], username, password)
    configure_bazarr(config_root, [radarr, sonarr], env)
    running = subprocess.run(["docker", "compose", "ps", "--services", "--status", "running"],
                             cwd=HERE, capture_output=True, text=True).stdout.split()
    if "kavita" in running:
        configure_kavita(username, password)
    print(f"\nDone. Log in as {username} with MEDIA_PASSWORD from {ENV_FILE} when asked.")


if __name__ == "__main__":
    main()
