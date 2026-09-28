"""Remove downloads that never start, so Radarr and Sonarr try another release.

Once a day, finds queue items stuck on "downloading metadata" or stalled with no
connections for longer than STALLED_HOURS, removes them from qBittorrent and
blocklists the release. Slow downloads and items waiting for import are left alone.
"""

import json
import os
import re
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

STALLED_HOURS = float(os.environ.get("STALLED_HOURS", "72"))
APPS = [("radarr", 7878, "includeUnknownMovieItems"), ("sonarr", 8989, "includeUnknownSeriesItems")]
STUCK = re.compile(r"metadata|stalled", re.I)


def call(method, url, key):
    request = urllib.request.Request(url, method=method, headers={"X-Api-Key": key})
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read()
    return json.loads(body) if body else None


def sweep():
    cutoff = datetime.now(timezone.utc) - timedelta(hours=STALLED_HOURS)
    for app, port, unknown in APPS:
        try:
            key = ET.parse(f"/keys/{app}/config.xml").getroot().findtext("ApiKey")
            base = f"http://{app}:{port}/api/v3/queue"
            queue = call("GET", f"{base}?pageSize=1000&{unknown}=true", key)["records"]
        except Exception as error:
            print(f"{app}: skipped, {error}")
            continue
        for item in queue:
            message = " ".join([item.get("errorMessage") or ""] +
                               [m for s in item.get("statusMessages", []) for m in s.get("messages", [])])
            added = item.get("added")
            if (item.get("trackedDownloadState") != "downloading" or not STUCK.search(message)
                    or not added or datetime.fromisoformat(added.replace("Z", "+00:00")) > cutoff):
                continue
            call("DELETE", f"{base}/{item['id']}?removeFromClient=true&blocklist=true", key)
            print(f"{app}: removed and blocklisted {item.get('title')} ({message.strip()})")


if __name__ == "__main__":
    time.sleep(300)  # Let Radarr and Sonarr finish starting.
    while True:
        sweep()
        time.sleep(24 * 3600)
