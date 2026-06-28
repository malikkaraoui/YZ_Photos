# YZPhotos — Dossier App Store (prêt à copier-coller)

Tout ce qu'il faut pour soumettre sur **App Store Connect**. Langue principale : **Français (France)**.

---

## 1. Identité

| Champ | Valeur |
|---|---|
| **Nom** (App Store, ≤ 30) | `YZPhotos` |
| **Sous-titre** (≤ 30) | `Trie tes photos sur disque` |
| **Bundle ID** | `com.karaoui.YZPhotos` |
| **Catégorie principale** | Photo et vidéo |
| **Catégorie secondaire** | Utilitaires |
| **Classification d'âge** | 4+ (aucun contenu répréhensible) |
| **Prix** | (à définir — gratuit ou payant) |
| **Plateformes** | iPhone + iPad (Universal) |

> Sous-titre alternatif si tu veux plus de mots-clés : `Tri photos sur SSD, NAS, SMB` (28).

---

## 2. Mots-clés (≤ 100 caractères, séparés par des virgules, SANS espaces)

```
tri,photos,vidéos,doublons,SSD,SMB,NAS,disque,USB-C,externe,corbeille,nettoyer,Freebox,rafales,trier
```

> Ne répète PAS les mots déjà dans le nom/sous-titre (Apple les indexe quand même). N'utilise pas d'espaces (ça gaspille des caractères).

---

## 3. Description (≤ 4000 caractères)

```
YZPhotos, c'est le tri de photos et vidéos pensé pour les DISQUES — ton SSD USB-C, ton NAS ou ta Freebox en SMB. Tu branches, et tu tries directement sur le disque, sans tout importer sur l'iPhone ou l'iPad.

TRIER D'UN GESTE
Une carte, un glissement : à droite tu gardes, à gauche tu jettes. Plein écran, zoom, lecture vidéo intégrée. Le deck précharge les images suivantes pour un défilement fluide, même sur des dizaines de milliers de fichiers.

REPÉRER ET FUSIONNER LES DOUBLONS
Détection des copies strictement identiques (vérifiées octet par octet) ET des quasi-doublons (rafales, recompressions). « Fusionner tout » garde automatiquement la meilleure de chaque groupe (la plus haute résolution) et envoie le reste à la corbeille — récupère des dizaines de Go en quelques gestes.

UNE CORBEILLE QUI PARDONNE
Rien n'est effacé tant que tu ne vides pas la corbeille. Tu peux restaurer à tout moment ce que tu as mis de côté.

PENSÉ POUR LES GROSSES BIBLIOTHÈQUES
100 000 fichiers ? Aucun souci. Grilles Photos, Vidéos et Par taille. Rangement par dossier, taille, date ou genre (croissant ou décroissant d'un re-clic), indicateur mois/année au défilement, statistiques et jauge de capacité.

PLUSIEURS DISQUES, CHACUN SA MÉMOIRE
Chaque disque est reconnu par son identifiant unique : son tri, ses doublons et sa corbeille restent enregistrés sur l'appareil même quand il est débranché. Branche tes disques à tour de rôle sans jamais rien mélanger.

PRIVÉ PAR NATURE
Tout reste entre ton appareil et ton disque. Aucune donnée envoyée ailleurs, aucun compte, aucun pistage, aucune publicité.

— Compatible disques USB-C et disques réseau SMB (NAS, Freebox, etc.).
— Partage/export d'une photo ou vidéo vers Photos, Fichiers ou AirDrop.
— Design Liquid Glass sur iOS 26.

Branche, glisse, range. C'est tout.
```

---

## 4. Texte promotionnel (≤ 170 caractères, modifiable sans nouvelle version)

```
Branche ton SSD ou ton NAS et trie tes photos et vidéos directement sur le disque : glisse pour garder ou jeter, fusionne les doublons, récupère depuis la corbeille.
```

---

## 5. Nouveautés de cette version (release notes — v1.0)

```
Première version de YZPhotos !
Trie tes photos et vidéos directement sur tes disques USB-C et réseau (SMB / NAS / Freebox) :
• Deck à glisser : garde ou jette d'un geste
• Détection et fusion des doublons (garde la meilleure)
• Corbeille récupérable
• Grilles Photos / Vidéos / Par taille, rangement multi-critères
• Plusieurs disques mémorisés, statistiques et jauge de capacité
Tout reste privé, entre ton appareil et ton disque.
```

---

## 6. URLs (obligatoires / recommandées)

| Champ | Valeur |
|---|---|
| **URL d'assistance** (obligatoire) | _à fournir_ (ex. une page GitHub, un site, ou un mailto:karaoui.malik@gmail.com via une page) |
| **URL marketing** (optionnel) | _à fournir_ |
| **URL politique de confidentialité** (obligatoire) | _à fournir_ — voir §7 pour le contenu type |
| **E-mail de contact (App Review)** | karaoui.malik@gmail.com |

> Minimum viable : une simple page web (même GitHub Pages) avec la politique de confidentialité + un e-mail de contact suffit pour l'URL d'assistance ET de confidentialité.

---

## 7. Confidentialité (Privacy)

**Étiquette de confidentialité (Privacy Nutrition Label) : « Aucune donnée collectée ».**
L'app ne collecte, ne transmet et ne suit AUCUNE donnée. Tout reste en local (appareil + disque). Pas d'analytics, pas de SDK tiers de tracking (GRDB et AMSMB2 sont des bibliothèques locales).

**Politique de confidentialité (texte type à héberger) :**
```
YZPhotos ne collecte aucune donnée personnelle. L'application lit vos photos et
vidéos uniquement depuis le disque que vous branchez (USB-C ou réseau SMB), pour
les afficher et les trier sur votre appareil. Aucune donnée n'est transmise à un
serveur, à l'éditeur ou à un tiers. L'accès au réseau local sert exclusivement à
joindre votre disque SMB. Contact : karaoui.malik@gmail.com
```

**Chaînes d'usage (déjà dans l'app) :**
- `NSLocalNetworkUsageDescription` ✅ (connexion au disque SMB).
- Pas besoin de Photos/Caméra/Micro/Localisation (l'app n'y accède pas ; l'export passe par la feuille de partage système).

---

## 8. Conformité à l'export (chiffrement)

✅ **Réglé dans le build** : `ITSAppUsesNonExemptEncryption = false` ajouté à l'Info.plist.
L'app n'utilise que des protocoles standards (SMB, HTTPS système) → exemptés. Plus de question « Export Compliance » à chaque envoi.

---

## 9. Icône

✅ **Conforme.** L'app fournit l'icône **1024×1024** (variantes claire, sombre, teintée) en source unique — Xcode génère automatiquement toutes les tailles. C'est le format moderne attendu par l'App Store. **Rien à refaire.**

---

## 10. Captures d'écran (illustrations App Store)

### Tailles REQUISES (App Store Connect, 2025)

| Appareil | Résolution (portrait) | Comment la capturer |
|---|---|---|
| **iPad 13"** | **2048 × 2732** | ✅ Directement sur ton **iPad Air 13" M4** (capture d'écran native). |
| **iPhone 6.9"** | **1290 × 2796** | ⚠️ Ton iPhone 12 Pro (6,1") est **trop petit** → voir ci-dessous. |

> Apple exige des captures **6.9"** (ou 6.5" : 1242×2688) pour iPhone, et **13"** (ou 12.9") pour iPad. Min. 1 capture par taille, **3 à 5 recommandées**, jusqu'à 10.

**iPhone — comment obtenir du 6.9" :**
Lance l'app dans le **simulateur iPhone 16 Pro Max** (6,9") : il partage le réseau du Mac, donc la connexion **SMB à la Freebox (192.168.0.83) fonctionne** → tu peux montrer du vrai contenu. Capture avec `Cmd+S` dans le simulateur. (Le simulateur sert ici UNIQUEMENT à produire les images aux bonnes dimensions, pas à tester.)

### Les 5 captures à faire (même scénario sur iPad et iPhone)

1. **Le deck de tri** — carte plein cadre + boutons poubelle/garder. Légende : « Trie d'un seul geste. »
2. **Les doublons** — groupes + bouton « Fusionner tout ». Légende : « Repère et fusionne les doublons. »
3. **La grille Photos** — mosaïque + menu « Ranger ». Légende : « Toute ta bibliothèque, rangée. »
4. **La corbeille** — fichiers récupérables. Légende : « Rien n'est perdu : corbeille récupérable. »
5. **Réglages / disques** — disque branché en évidence + jauge de capacité. Légende : « Plusieurs disques, chacun sa mémoire. »

> Astuce : ajoute les légendes par-dessus les captures (texte court, fond dégradé) pour un rendu pro. Optionnel mais ça vend beaucoup mieux.

---

## 11. Checklist de soumission

- [ ] Compte **Apple Developer payant** (99 $/an) — requis pour publier (le compte gratuit ne suffit pas).
- [ ] Bundle ID `com.karaoui.YZPhotos` créé dans le portail développeur.
- [ ] Fiche app créée sur **App Store Connect** (nom, langue FR).
- [ ] Métadonnées copiées (§1 à §6).
- [ ] Étiquette de confidentialité = « Aucune donnée collectée » (§7).
- [ ] URL d'assistance + URL de confidentialité en ligne (§6).
- [ ] Captures iPad 13" + iPhone 6.9" uploadées (§10).
- [ ] Archive **Release** (pas Debug) signée avec un certificat de **distribution**, uploadée via Xcode/Transporter.
  - ⚠️ Le projet est en Debug + compte gratuit aujourd'hui : il faudra une **archive Release** + provisioning **App Store**.
- [ ] Build sélectionné dans la version, classification d'âge remplie, prix/disponibilité définis.
- [ ] « Envoyer pour examen ».

---

## 12. Points d'attention avant envoi

- **Build Release & signature distribution** : aujourd'hui on déploie en Debug avec un compte gratuit (profils 7 jours). Pour l'App Store il faut archiver en **Release** avec un certificat **Apple Distribution** + profil App Store. (Le code, lui, est prêt.)
- **Démo pour App Review** : l'app a besoin d'un disque branché. Comme le testeur Apple n'aura pas ton SSD, prévois dans les **notes pour l'examinateur** une explication claire (« nécessite un disque USB-C ou un partage réseau SMB ; sans disque, l'app affiche l'écran d'accueil de connexion ») et, si possible, **un partage SMB de test accessible** + identifiants, OU des captures/vidéo de démonstration. Sinon risque de rejet « impossible de tester ».
- **Nom « YZPhotos »** : vérifie qu'il est disponible sur l'App Store (pas de conflit de marque).
