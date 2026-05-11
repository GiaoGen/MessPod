import os
import re
from html import unescape
from typing import Dict, List

import requests
from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from youtube_transcript_api import (
    NoTranscriptFound,
    TranscriptsDisabled,
    YouTubeTranscriptApi,
)


DEFAULT_LANGUAGES = ["en", "zh-Hans", "zh-Hant", "ja"]
SENTENCE_PART_RE = re.compile(
    r".+?[\.\!\?\u3002\uff01\uff1f]+[\"'\u201d\u2019\)\]]*|.+$"
)
SENTENCE_END_RE = re.compile(
    r"[\.\!\?\u3002\uff01\uff1f]+[\"'\u201d\u2019\)\]]*$"
)
MAX_GAP_SECONDS = 1.4
THUMBNAIL_URLS = [
    "https://i.ytimg.com/vi/{video_id}/hqdefault.jpg",
    "https://i.ytimg.com/vi_webp/{video_id}/hqdefault.webp",
    "https://i.ytimg.com/vi/{video_id}/mqdefault.jpg",
    "https://img.youtube.com/vi/{video_id}/0.jpg",
]

proxy_url = os.getenv("YT_PROXY")
if proxy_url:
    os.environ["HTTP_PROXY"] = proxy_url
    os.environ["HTTPS_PROXY"] = proxy_url

app = FastAPI(title="ytpodcast transcript api")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.get("/videos/{video_id}")
def get_video(video_id: str) -> Dict:
    title = fetch_title(video_id)
    subtitles = fetch_transcript(video_id)
    return {
        "videoId": video_id,
        "title": title,
        "durationSeconds": 0,
        "subtitles": subtitles,
    }


@app.get("/videos/{video_id}/thumbnail")
def get_thumbnail(video_id: str) -> Response:
    for template in THUMBNAIL_URLS:
        url = template.format(video_id=video_id)
        try:
            response = requests.get(
                url,
                timeout=10,
                headers={
                    "User-Agent": (
                        "Mozilla/5.0 (Linux; Android 13) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/120.0 Mobile Safari/537.36"
                    )
                },
            )
            if response.status_code == 200 and response.content:
                content_type = response.headers.get("content-type", "image/jpeg")
                return Response(content=response.content, media_type=content_type)
        except Exception:
            continue

    raise HTTPException(status_code=404, detail="thumbnail not found")


def fetch_title(video_id: str) -> str:
    url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        html = response.text
        start = html.find("<title>")
        end = html.find("</title>", start)
        if start < 0 or end < 0:
            return f"YouTube video - {video_id}"

        raw_title = html[start + len("<title>") : end]
        return unescape(raw_title).replace(" - YouTube", "").strip()
    except Exception:
        return f"YouTube video - {video_id}"


def fetch_transcript(video_id: str) -> List[Dict]:
    try:
        transcript = YouTubeTranscriptApi().fetch(
            video_id,
            languages=DEFAULT_LANGUAGES,
        )
    except TranscriptsDisabled as error:
        raise HTTPException(status_code=404, detail="transcripts disabled") from error
    except NoTranscriptFound as error:
        raise HTTPException(status_code=404, detail="no transcript found") from error
    except Exception as error:
        raise HTTPException(status_code=502, detail=str(error)) from error

    return merge_transcript_snippets(transcript)


def merge_transcript_snippets(transcript) -> List[Dict]:
    lines = []
    current_text = []
    current_start = None
    current_end = None
    previous_end = None

    for snippet in transcript:
        text = normalize_subtitle_text(snippet.text)
        if not text:
            continue

        start = float(snippet.start)
        end = float(snippet.start + snippet.duration)
        gap = 0 if previous_end is None else start - previous_end

        if current_text and gap > MAX_GAP_SECONDS and is_sentence_complete(
            current_text
        ):
            append_subtitle_line(lines, current_start, current_end, current_text)
            current_text = []
            current_start = None
            current_end = None

        parts = split_text_by_sentence_end(text)
        for part_index, part in enumerate(parts):
            if not part:
                continue

            part_start = start if part_index == 0 else current_end
            part_end = estimate_part_end(start, end, parts, part_index)
            if current_start is None:
                current_start = part_start

            current_text.append(part)
            current_end = part_end

            if SENTENCE_END_RE.search(part):
                append_subtitle_line(lines, current_start, current_end, current_text)
                current_text = []
                current_start = None
                current_end = None

        previous_end = end

    if current_text:
        append_subtitle_line(lines, current_start, current_end, current_text)

    return lines


def split_text_by_sentence_end(text: str) -> List[str]:
    parts = [match.group(0).strip() for match in SENTENCE_PART_RE.finditer(text)]
    return [part for part in parts if part]


def is_sentence_complete(text_parts: List[str]) -> bool:
    return bool(SENTENCE_END_RE.search(" ".join(text_parts).strip()))


def estimate_part_end(start: float, end: float, parts: List[str], index: int) -> float:
    if len(parts) <= 1:
        return end

    total_chars = sum(max(1, len(part)) for part in parts)
    elapsed_chars = sum(max(1, len(part)) for part in parts[: index + 1])
    ratio = elapsed_chars / total_chars
    return start + ((end - start) * ratio)


def append_subtitle_line(lines, start, end, text_parts) -> None:
    if start is None or end is None:
        return

    text = " ".join(text_parts).strip()
    if not text:
        return

    lines.append(
        {
            "start": float(start),
            "duration": max(0.1, float(end - start)),
            "text": text,
        }
    )


def normalize_subtitle_text(text: str) -> str:
    text = unescape(text or "")
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()
