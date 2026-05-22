# Conventions PostgreSQL pour les projets protegR2

## Principe général

Chaque application utilisant protegR2 avec un backend PostgreSQL suit une structure standardisée :
- **Une DB par projet/client** — isolation complète des données
- **Un schéma par package R** — séparation claire des responsabilités
- **Un user PostgreSQL par DB** — credentials séparés, permissions minimales

---

## Structure type

```
Instance PostgreSQL (VPS)
│
├── DB: finance                  ← projet "finance" (app personnelle)
│   ├── schema: protegr2         ← tables gérées par protegR2
│   └── schema: stocktools       ← tables gérées par le package {stockTools}
│
├── DB: avn_pascan               ← projet client "pascan"
│   ├── schema: protegr2
│   ├── schema: logpages         ← tables gérées par le package {logpages}
│   └── schema: otp              ← tables gérées par le package {otp}
│
└── DB: avn_cie2                 ← autre projet client
    ├── schema: protegr2
    ├── schema: logpages
    └── schema: otp
```

**Conventions de nommage :**
- DB : nom du projet ou client (`finance`, `avn_pascan`, etc.)
- Schéma : nom du package R qui possède ces tables (minuscules, sans tirets)
- User PostgreSQL : même nom que la DB (`finance`, `avn_pascan`, etc.)

---

## Schéma `protegr2` — tables standards

Ce schéma est **identique dans toutes les DB**. Il est créé automatiquement par protegR2 lors de l'initialisation d'un projet postgres.

> ⚠️ Tables à définir — section à compléter lors de l'implémentation de la Phase 5.

Tables prévues :
- `protegr2.user_config` — préférences et config utilisateur propres au projet
- `protegr2.audit_log` — historique des connexions/déconnexions (optionnel)

---

## Schéma par package

Chaque package R qui utilise PostgreSQL :
- Connaît son propre nom de schéma (hardcodé dans le package)
- Crée ses tables dans ce schéma uniquement
- Ne lit/écrit jamais dans le schéma d'un autre package

Exemple pour `{stockTools}` :
```sql
-- Toutes les tables sont préfixées du schéma
SELECT * FROM stocktools.stockprice WHERE ticker = 'AAPL';
```

---

## Credentials et connexion

### Configuration dans protegR2 (court terme)

Les credentials sont stockés dans `config_global$protegR2$db` sur S3 :

```r
config_global$protegR2$db <- list(
  host     = "localhost",   # tunnel SSH en local, IP VPS en prod
  port     = 5432,
  dbname   = "finance",
  user     = "finance",
  password = "..."
)
```

> ⚠️ À terme, migrer vers des variables d'environnement (`.Renviron` en local,
> variables d'environnement du serveur en prod) pour ne jamais avoir de credentials
> dans des fichiers sauvegardés sur S3.

### Connexion locale via tunnel SSH

En développement local, ouvrir le tunnel avant de lancer l'app :

```bash
ssh -L 5432:localhost:5432 user@ip_vps -N
```

Ensuite la connexion R utilise `host = "localhost"` comme en prod.

### Connexion psql en ligne de commande

```bash
# Via tunnel SSH (local)
psql -h localhost -p 5432 -U finance -d finance

# Directement sur le VPS
psql -U finance -d finance
```

---

## Création d'un nouveau projet postgres

Séquence standard lors de la création d'une nouvelle DB :

```sql
-- 1. Connecté en tant que superuser (ex. postgres)
CREATE DATABASE nom_projet;
CREATE USER nom_projet WITH PASSWORD 'mot_de_passe';

-- 2. Connecté à la nouvelle DB
\c nom_projet

-- 3. Créer les schémas
CREATE SCHEMA protegr2;
CREATE SCHEMA nom_package;

-- 4. Donner les permissions au user du projet
GRANT CONNECT ON DATABASE nom_projet TO nom_projet;
GRANT USAGE, CREATE ON SCHEMA protegr2 TO nom_projet;
GRANT USAGE, CREATE ON SCHEMA nom_package TO nom_projet;
ALTER DEFAULT PRIVILEGES IN SCHEMA protegr2 GRANT ALL ON TABLES TO nom_projet;
ALTER DEFAULT PRIVILEGES IN SCHEMA protegr2 GRANT ALL ON SEQUENCES TO nom_projet;
ALTER DEFAULT PRIVILEGES IN SCHEMA nom_package GRANT ALL ON TABLES TO nom_projet;
ALTER DEFAULT PRIVILEGES IN SCHEMA nom_package GRANT ALL ON SEQUENCES TO nom_projet;

-- 5. Transférer la propriété des schémas
ALTER SCHEMA protegr2 OWNER TO nom_projet;
ALTER SCHEMA nom_package OWNER TO nom_projet;
```

---

## Migration d'une DB existante

Si des tables existent dans le schéma `public` et doivent être déplacées :

```sql
-- Créer le schéma cible
CREATE SCHEMA nom_package;

-- Déplacer les tables
ALTER TABLE public.nom_table SET SCHEMA nom_package;
-- Répéter pour chaque table...

-- Transférer la propriété du schéma
ALTER SCHEMA nom_package OWNER TO nom_user;
```

---

*Document maintenu dans `inst/docs/postgres_conventions.md`*
