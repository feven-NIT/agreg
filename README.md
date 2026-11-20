# Agrégation Mathématiques 2027 — Rituel quotidien

Ce dossier organise ta préparation : **une fiche de cours + un exercice par jour**, généré automatiquement à 22h55 par un job launchd.

## Boucle quotidienne

```
22h55        ─► launchd exécute generer.sh
             ─► Claude lit progression.json + etat.json
             ─► Écrit fiches/YYYY-MM-DD.md (cours + exo + correction cachée)
             ─► Met à jour etat.json (jour+1, sujet_courant_id+1)

À ton réveil ─► Tu ouvres la fiche du jour
             ─► Tu bosses l'exercice sur papier (30-45 min)

Quand tu veux ─► agreg-valider photo.jpg
             ─► Claude lit ta rédaction, note ton raisonnement,
                donne un code de déblocage si validé
```

## Commandes utiles

Ajoute dans ton `~/.zshrc` :

```bash
alias agreg='cd ~/agreg && ls -1t fiches/ | head -5'
alias agreg-generer='~/agreg/generer.sh'
alias agreg-valider='~/agreg/valider.sh'
alias agreg-fiche='cat ~/agreg/fiches/$(date +%Y-%m-%d).md 2>/dev/null || ls -1t ~/agreg/fiches | head -1 | xargs -I{} cat ~/agreg/fiches/{}'
alias agreg-etat='cat ~/agreg/etat.json'
alias agreg-log='tail -30 ~/agreg/logs/launch.log'
```

### Valider une rédaction (texte uniquement, pas de photo)

```bash
agreg-valider                              # session interactive, tu colles ta rédac
agreg-valider redac.txt                    # depuis un fichier texte
echo "ma rédaction..." | agreg-valider -   # depuis stdin
```

Tu peux taper en Markdown + LaTeX (`$x^2$`) ou en abréviations (`=>`, `forall`, `in`, `ker`, `Im`…). Claude valide le raisonnement, pas la forme.

## Structure

```
~/agreg/
├── progression.json      # 150 sujets ordonnés (7 blocs, 15 mois)
├── etat.json             # jour courant, sujet_courant_id, historique
├── generer.sh            # script lancé par launchd
├── valider.sh            # workflow de validation
├── prompts/
│   ├── generer.md        # prompt pour la génération
│   └── valider.md        # prompt pour la validation
├── fiches/               # 1 fichier par jour : YYYY-MM-DD.md
├── validations/          # évaluations de tes rédactions
└── logs/                 # journaux d'exécution
```

## launchd

Job installé : `~/Library/LaunchAgents/fr.even.agreg.plist`

```bash
# Vérifier qu'il tourne
launchctl list | grep fr.even.agreg

# Désactiver temporairement
launchctl unload ~/Library/LaunchAgents/fr.even.agreg.plist

# Réactiver
launchctl load ~/Library/LaunchAgents/fr.even.agreg.plist

# Changer l'heure : éditer le .plist puis unload/load
```

## Prochaines étapes (hors MVP)

1. **Phase 2** — Accès téléphone (texte-only, pas de photo) :
   - Option A : formulaire Tally qui affiche l'exo + champ texte → webhook Mac via Cloudflare Tunnel.
   - Option B : page web statique privée (GitHub Pages / Vercel) + endpoint de validation.
   - Option C : l'app Claude mobile avec un prompt type et la fiche collée manuellement.
2. **Phase 3** — Blocage iOS :
   - Mode Concentration "Nuit Agrégation" à 23h bloquant toutes les apps distractives.
   - Raccourci qui ne peut désactiver le mode que si une validation réussie est détectée via l'API.

## Progression

7 blocs sur ~15 mois (nov 2026 → écrits 2027) :

| Bloc | Thème | Sujets | Période |
|------|-------|--------|---------|
| A | Algèbre : structures (groupes, anneaux, corps) | 30 | mois 1-3 |
| B | Algèbre linéaire et réduction | 25 | mois 3-4 |
| C | Analyse : topologie, calcul différentiel | 25 | mois 5-6 |
| D | Intégration, Fourier, analyse complexe | 20 | mois 7-8 |
| E | Probabilités et statistiques | 20 | mois 9-10 |
| F | Géométrie | 10 | mois 11 |
| G | Révisions, oraux, développements | 20 | mois 12-15 |

Total : **150 sujets** (extensible en ajoutant à `progression.json`).
