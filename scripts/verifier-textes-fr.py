#!/usr/bin/env python3
"""Liste les textes français visibles qui ne passent pas par le catalogue de traduction.
Usage : python3 scripts/verifier-textes-fr.py [racine]  → code 0 si rien, 1 sinon (liste fichier:ligne)."""
import json, re, sys, glob, os
R = sys.argv[1] if len(sys.argv) > 1 else '.'
cat = set(json.load(open(os.path.join(R, 'YZPhotos/Resources/Localizable.xcstrings')))['strings'].keys())
FR = re.compile(r"[éèêàùçôîœ]|\b(le|la|les|des|du|une|un|sur|aucun|aucune|disque|fichiers?|analyse|termin\w*|corbeille|garder|réglages|dossier|vidéos?|photos?|doublons?|connexion|erreur|moins|minute|reste|espace|sélectionnés|recherche)\b", re.I)
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
STRINGISH = re.compile(r'(->\s*String|:\s*String\s*[{=]|return\s+"|case [^:]+:\s*"|\?\s*"|:\s*"[^"]*"\s*$|String\(format|\+\s*"|"\s*\+|Text\(verbatim)')
IGNORE_FILES = ('Core/Logging/', 'Core/Scanning/MediaClassifier.swift', 'Core/Localization/LocalizationManager.swift')
bad = []
for f in sorted(glob.glob(os.path.join(R, 'YZPhotos/**/*.swift'), recursive=True)):
    if any(x in f for x in IGNORE_FILES): continue
    dbg = 0
    for i, l in enumerate(open(f).read().split('\n'), 1):
        s = l.strip()
        if s.startswith('#if DEBUG'): dbg += 1
        elif s.startswith('#endif') and dbg: dbg -= 1
        if dbg or s.startswith('//') or 'AppLog' in s or 'print(' in s or 'String(localized:' in s: continue
        for m in LIT.finditer(l):
            t = m.group(1)
            if len(t) < 3 or not FR.search(t) or (' ' not in t and re.fullmatch(r'[a-z.]+', t)): continue  # SF Symbols, clés techniques
            key = re.sub(r'\\\((?:[^()]|\([^()]*\))*\)', '%@', t)
            if key not in cat or STRINGISH.search(s):
                bad.append(f"{os.path.relpath(f, R)}:{i}: {t[:90]}")
for k, v in json.load(open(os.path.join(R, 'YZPhotos/Resources/Localizable.xcstrings')))['strings'].items():
    if v.get('shouldTranslate') is False: continue
    if not v.get('localizations', {}).get('en', {}).get('stringUnit', {}).get('value') and not v.get('localizations', {}).get('en', {}).get('variations'):
        bad.append(f"Localizable.xcstrings: clé sans anglais : {k[:90]}")
print('\n'.join(bad)); print(f"{len(bad)} texte(s) non traduit(s)")
sys.exit(1 if bad else 0)
