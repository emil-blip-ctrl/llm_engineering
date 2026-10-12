#!/usr/bin/env python3
"""
PII guard for Claude Code — TCS data protection policy.

Reads the user prompt from stdin (JSON: {"prompt": "..."}),
checks for personal data patterns, and exits 2 to block if found.

Patterns covered (Swiss + generic):
  - Numéro AVS/AHV (756.XXXX.XXXX.XX)
  - IBAN (CH / international)
  - Numéro de carte bancaire
  - Numéro de téléphone suisse (+41 / 0041 / 0XX)
  - Adresse e-mail
  - Numéro d'identification entreprise (CHE-XXX.XXX.XXX)
  - Numéro de passeport / carte d'identité
  - Date de naissance (formats courants DD/MM/YYYY, DD.MM.YYYY)
  - Adresse postale complète (heuristique)
  - Numéro de client / ID candidat (heuristique chiffres longs)
"""

from __future__ import annotations

import json
import re
import sys

PATTERNS: list[tuple[str, str]] = [
    # Swiss AVS/AHV number  756.XXXX.XXXX.XX
    (r"\b756\.\d{4}\.\d{4}\.\d{2}\b", "Numéro AVS/AHV"),
    # IBAN
    (r"\b[A-Z]{2}\d{2}[A-Z0-9]{4}\d{7}[A-Z0-9]{0,16}\b", "IBAN"),
    # Credit card  (4×4 digits with optional space/dash)
    (r"\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b", "Numéro de carte bancaire"),
    # Swiss phone  +41 / 0041 / 0XX format
    (r"\b(\+41|0041|0)[1-9]\d{1,2}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}\b", "Numéro de téléphone suisse"),
    # E-mail address
    (r"\b[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}\b", "Adresse e-mail"),
    # Swiss company UID  CHE-XXX.XXX.XXX
    (r"\bCHE-\d{3}\.\d{3}\.\d{3}\b", "Numéro IDE entreprise (CHE)"),
    # Passport / ID mention near digits
    (r"\b(passport|passeport|carte\s+d.identit[eé]|permis\s+[A-C]|N°\s*[\w\d]+)\b", "Document d'identité"),
    # Date of birth formats  DD/MM/YYYY  DD.MM.YYYY  YYYY-MM-DD
    (r"\b\d{1,2}[./\-]\d{1,2}[./\-]\d{4}\b|\b\d{4}-\d{2}-\d{2}\b", "Date (potentiellement de naissance)"),
    # Swiss postal address heuristic  (digits + "rue"|"avenue"|"chemin" etc.)
    (r"\b\d{1,4}\s+(?:rue|avenue|av\.|chemin|route|boulevard|bd\.|place|allée)\b", "Adresse postale"),
    # Long numeric identifiers ≥ 8 consecutive digits (client IDs, member numbers…)
    (r"\b\d{8,}\b", "Identifiant numérique long (potentiel numéro client/membre)"),
]


def main() -> None:
    try:
        data = json.load(sys.stdin)
        text: str = data.get("prompt", "")
    except Exception:
        sys.exit(0)  # can't parse input — let it through

    if not text:
        sys.exit(0)

    hits: list[tuple[str, str]] = []
    for pattern, label in PATTERNS:
        m = re.search(pattern, text, re.IGNORECASE)
        if m:
            hits.append((label, m.group()))

    if not hits:
        sys.exit(0)

    types = " | ".join(sorted({label for label, _ in hits}))

    print("=" * 70)
    print("BLOQUE -- Politique de protection des donnees TCS")
    print("=" * 70)
    print()
    print(f"  Donnees personnelles detectees : {types}")
    print()
    print("  La saisie de donnees personnelles dans Claude Code est interdite")
    print("  par la Directive de protection des donnees TCS, conformement a la")
    print("  LPD (Loi federale sur la protection des donnees) et au RGPD.")
    print()
    print("  Anonymisez les donnees avant de les saisir")
    print("  Utilisez des donnees synthetiques ou des valeurs fictives")
    print("  En cas de doute, contactez : dpo@tcs.ch")
    print()
    print("  Ref. : Directive SI-04 -- Usage des outils IA au TCS")
    print("=" * 70)

    sys.exit(2)  # exit 2 blocks the prompt submission in Claude Code


if __name__ == "__main__":
    main()
