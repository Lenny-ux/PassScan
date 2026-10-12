# PassScan 🚇

App iPhone pour garder toutes tes cartes de transport au même endroit :

- **Scan NFC** des cartes bus / train / métro (UID, type de puce, données NDEF)
- **Scan QR / Aztec / PDF417 / code-barres** avec la caméra
- **Import depuis une capture d'écran** (billet reçu par mail, PDF…)
- **Affichage du code en grand** avec luminosité max pour passer les portiques
- **Personnalisation** : nom, couleur, icône de chaque carte + titre, couleur et thème de l'app

---

## 1. Mettre le projet sur GitHub

1. Va sur github.com → **New repository** → nom `PassScan` → **Create**
2. Clique **uploading an existing file**
3. Glisse **tout le contenu** du dossier `PassScan` (y compris le dossier `.github`)
4. **Commit changes**

> Si le dossier `.github` ne passe pas (il est caché sur Mac) : **Add file → Create new file**, tape le nom `.github/workflows/build.yml` et colle le contenu du fichier.

## 2. Récupérer le .ipa

1. Onglet **Actions** → le build « Build IPA » se lance tout seul (≈ 5 min)
2. Quand c'est vert ✅ → va dans **Releases** (colonne de droite de la page du repo)
3. Télécharge **PassScan.ipa**

Pour relancer un build à la main : **Actions → Build IPA → Run workflow**.

## 3. Installer avec Sideloadly

1. Branche l'iPhone au PC, ouvre **Sideloadly**
2. Glisse `PassScan.ipa` dedans, mets ton Apple ID
3. (Optionnel) **Advanced options → App name** pour changer le nom sous l'icône
4. **Start**
5. Sur l'iPhone : **Réglages → Général → VPN et gestion de l'appareil** → fais confiance à ton Apple ID
6. iOS 16+ : active le **Mode développeur** (Réglages → Confidentialité et sécurité)

Avec un Apple ID gratuit, l'app est à réinstaller tous les **7 jours**.

---

## ⚠️ À savoir sur le NFC

- **Apple ID gratuit** : Apple n'autorise pas le NFC pour les comptes gratuits → la partie QR/codes marche, mais le scan NFC affichera une erreur. Pour le NFC il faut un **compte développeur payant** (99 $/an) dans Sideloadly, ou **TrollStore** si ton iOS est compatible.
- L'iPhone lit les puces **13,56 MHz** (MIFARE, Calypso/Navigo, FeliCa, ISO 15693). Les badges **RFID 125 kHz** ne sont pas lisibles.
- Le **solde / les abonnements** sont chiffrés sur la plupart des cartes de transport : l'app lit l'identifiant et le type, pas le contenu protégé.
