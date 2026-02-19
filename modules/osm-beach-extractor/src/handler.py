"""Lambda handler that queries the Overpass API for OSM beach data and stores results in S3."""

import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timezone

S3_BUCKET = os.environ["S3_BUCKET"]
S3_PREFIX = os.environ["S3_PREFIX"]

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

OVERPASS_QUERY = """
[out:json][timeout:250];
(
  node["natural"="beach"];
  way["natural"="beach"];
  relation["natural"="beach"];
);
out center;
"""

TAGS_OF_INTEREST = {
    "natural",
    "surface",
    "access",
    "nudism",
    "name",
    "supervised",
    "lit",
    "wheelchair",
    "tourism",
    "leisure",
    "amenity",
    "sport",
}


def _query_overpass():
    """POST the OverpassQL query and return the parsed JSON response."""
    data = urllib.parse.urlencode({"data": OVERPASS_QUERY}).encode()
    req = urllib.request.Request(OVERPASS_URL, data=data, method="POST")
    with urllib.request.urlopen(req, timeout=600) as resp:
        return json.loads(resp.read().decode())


def _extract_features(elements):
    """Extract beach features with relevant tags from Overpass elements."""
    features = []
    for el in elements:
        tags = el.get("tags", {})
        if not tags:
            continue

        feature = {
            "id": el["id"],
            "type": el["type"],
            "tags": {k: v for k, v in tags.items() if k in TAGS_OF_INTEREST},
        }

        if el["type"] == "node":
            feature["lat"] = el.get("lat")
            feature["lon"] = el.get("lon")
        else:
            center = el.get("center", {})
            feature["lat"] = center.get("lat")
            feature["lon"] = center.get("lon")

        features.append(feature)
    return features


def _upload_to_s3(payload):
    """Upload JSON payload to S3."""
    import boto3

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    key = f"{S3_PREFIX}/{today}/beaches.json"

    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=key,
        Body=json.dumps(payload, ensure_ascii=False).encode(),
        ContentType="application/json",
    )
    return key



def handler(event, context):
    raw = _query_overpass()
    features = _extract_features(raw.get("elements", []))

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": "openstreetmap/overpass",
        "count": len(features),
        "beaches": features,
    }

    key = _upload_to_s3(payload)
    msg = f"Uploaded {len(features)} beaches to s3://{S3_BUCKET}/{key}"
    print(msg)
    return {"statusCode": 200, "body": msg}
