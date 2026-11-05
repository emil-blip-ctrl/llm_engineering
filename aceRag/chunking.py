
"""
Chunking utilities for the ACE RAG project.

Responsibilities:
- Read the edited ACE documentation text file.
- Split the document into chunks with configurable overlap.
- Preserve page markers when they are present in the source text.
- Assign stable chunk IDs for reproducible indexing.

This module does not call an LLM or generate embeddings.
"""

from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Any


# Adjust these if the source text uses a different page-marker format.
PAGE_MARKER_PATTERNS = [
    re.compile(r"^\s*---\s*PAGE\s+(\d+)\s*---\s*$", re.IGNORECASE),
    re.compile(r"^\s*\[\s*PAGE\s+(\d+)\s*\]\s*$", re.IGNORECASE),
    re.compile(r"^\s*Page\s+(\d+)\s*$", re.IGNORECASE),
]

DEFAULT_CHUNK_SIZE = 4600
DEFAULT_CHUNK_OVERLAP = 1000


def read_document(path: str | Path) -> str:
    """Read the edited documentation text file."""
    document_path = Path(path)

    if not document_path.exists():
        raise FileNotFoundError(
            f"Documentation file not found: {document_path}"
        )

    if not document_path.is_file():
        raise ValueError(
            f"Documentation path is not a file: {document_path}"
        )

    text = document_path.read_text(encoding="utf-8")

    if not text.strip():
        raise ValueError(
            f"Documentation file is empty: {document_path}"
        )

    return text.replace("\r\n", "\n").replace("\r", "\n")


def _find_page_number(line: str) -> int | None:
    """Return a page number if the line matches a known page marker."""
    for pattern in PAGE_MARKER_PATTERNS:
        match = pattern.match(line)
        if match:
            return int(match.group(1))

    return None


def _split_into_page_sections(
    text: str,
    default_page: int = 1,
) -> list[dict[str, Any]]:
    """
    Split text into page sections.

    Recognized page-marker lines are removed from the chunk text.
    Text before the first marker is assigned default_page.
    If the file has no recognized page markers, the whole document
    is assigned default_page.
    """
    sections: list[dict[str, Any]] = []

    current_page = default_page
    current_lines: list[str] = []

    for line in text.split("\n"):
        marker_page = _find_page_number(line)

        if marker_page is not None:
            content = "\n".join(current_lines).strip()

            if content:
                sections.append(
                    {
                        "page": current_page,
                        "text": content,
                    }
                )

            current_page = marker_page
            current_lines = []
        else:
            current_lines.append(line)

    content = "\n".join(current_lines).strip()

    if content:
        sections.append(
            {
                "page": current_page,
                "text": content,
            }
        )

    if not sections:
        return [{"page": default_page, "text": text.strip()}]

    return sections


def _split_text_with_overlap(
    text: str,
    chunk_size: int,
    chunk_overlap: int,
) -> list[str]:
    """
    Split text into overlapping character-based chunks.

    The splitter prefers paragraph, line, or word boundaries near
    the target size. It falls back to a hard boundary for long text
    without natural breakpoints.
    """
    if chunk_size < 1:
        raise ValueError("chunk_size must be at least 1.")

    if chunk_overlap < 0:
        raise ValueError("chunk_overlap cannot be negative.")

    if chunk_overlap >= chunk_size:
        raise ValueError(
            "chunk_overlap must be smaller than chunk_size."
        )

    text = text.strip()

    if not text:
        return []

    chunks: list[str] = []
    start = 0
    text_length = len(text)

    while start < text_length:
        target_end = min(start + chunk_size, text_length)
        end = target_end

        if target_end < text_length:
            # Prefer a natural boundary in the latter part of the
            # candidate chunk to avoid excessively short chunks.
            minimum_end = start + int(chunk_size * 0.65)

            boundary_candidates = [
                text.rfind("\n\n", minimum_end, target_end),
                text.rfind("\n", minimum_end, target_end),
                text.rfind(". ", minimum_end, target_end),
                text.rfind(" ", minimum_end, target_end),
            ]

            best_boundary = max(boundary_candidates)

            if best_boundary >= minimum_end:
                # Include the boundary character(s) in this chunk.
                end = best_boundary + 1

        chunk = text[start:end].strip()

        if chunk:
            chunks.append(chunk)

        if end >= text_length:
            break

        # Ensure forward progress even if stripping removes whitespace.
        next_start = max(start + 1, end - chunk_overlap)

        # Avoid starting the next chunk in the middle of a word.
        while (
            next_start < end
            and next_start < text_length
            and not text[next_start - 1].isspace()
            and not text[next_start].isspace()
        ):
            next_start += 1

        start = next_start

    return chunks


def _make_chunk_id(
    page: int,
    chunk_index: int,
    text: str,
) -> str:
    """
    Generate a deterministic chunk ID.

    The content digest helps detect changes when a document is edited.
    Chunk index and page number keep IDs readable.
    """
    digest = hashlib.sha1(
        text.encode("utf-8")
    ).hexdigest()[:10]

    return f"ace-p{page:04d}-c{chunk_index:04d}-{digest}"


def chunk_document(
    text: str,
    chunk_size: int = DEFAULT_CHUNK_SIZE,
    chunk_overlap: int = DEFAULT_CHUNK_OVERLAP,
    source: str = "ace12-user_guide.txt",
    default_page: int = 1,
) -> list[dict[str, Any]]:
    """
    Convert documentation text into chunks ready for metadata enrichment.

    Returns dictionaries with:
        id: Stable chunk ID.
        text: Original chunk text.
        metadata: Source filename, page number, and chunk index.

    Note:
        Page numbers are accurate only when the source text contains
        recognizable page markers. Otherwise, default_page is used.
    """
    if not text.strip():
        raise ValueError("Cannot chunk an empty document.")

    page_sections = _split_into_page_sections(
        text,
        default_page=default_page,
    )

    chunks: list[dict[str, Any]] = []
    page_chunk_counts: dict[int, int] = {}

    for section in page_sections:
        page = int(section["page"])
        section_text = str(section["text"])

        section_chunks = _split_text_with_overlap(
            section_text,
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
        )

        for chunk_text in section_chunks:
            page_chunk_counts[page] = (
                page_chunk_counts.get(page, 0) + 1
            )
            page_chunk_index = page_chunk_counts[page]

            chunk_id = _make_chunk_id(
                page=page,
                chunk_index=page_chunk_index,
                text=chunk_text,
            )

            chunks.append(
                {
                    "id": chunk_id,
                    "text": chunk_text,
                    "metadata": {
                        "source": source,
                        "page": page,
                        "chunk_index": page_chunk_index,
                    },
                }
            )

    return chunks


def chunk_document_file(
    path: str | Path,
    chunk_size: int = DEFAULT_CHUNK_SIZE,
    chunk_overlap: int = DEFAULT_CHUNK_OVERLAP,
    default_page: int = 1,
) -> list[dict[str, Any]]:
    """Read a text file and chunk it using its filename as the source."""
    document_path = Path(path)
    text = read_document(document_path)

    return chunk_document(
        text=text,
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        source=document_path.name,
        default_page=default_page,
    )
