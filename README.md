# OpenReview

Database project for the university course. A system to manage academic conferences: articles, reviews, organizers, etc.

## What's inside

```
sql/            -- oracle SQL (tables, triggers, procedures, test data, indexes)
app/            -- flask web app (python + jinja2 templates)
docs/           -- latex documentation (report + diagrams)
docker-compose.yml
```

## Architecture

Three layers:
- **Oracle 21c XE** -- the database, has all the tables, triggers and stored procedures
- **Flask + Gunicorn** -- python web server, calls the stored procedures
- **HTML + Tailwind CSS** -- frontend, just server-side rendered templates

Everything runs in Docker (2 containers).

## How to run

You need Docker installed.

```bash
docker compose up --build
```

Then open http://localhost:5000

First time it takes a few minutes because Oracle needs to initialize. After that it's fast because the data is saved in a volume.

## What the app does

- `/conferences` -- list all conferences
- `/conference/<acronym>/accepted-articles` -- see accepted articles for a conference
- `/submit-review` -- submit a review (enter reviewer code first)
- `/reviewer/<code>/assignments` -- see articles assigned to a reviewer

## SQL structure

`sql/00_full_setup.sql` has everything concatenated in the right order — that's what Docker runs on startup. The other files let you apply or test individual parts without re-running the whole setup.

The `sql/triggers/` folder contains one file per trigger. Useful to reapply a single trigger after editing it in SQLcl without reloading the whole schema.

## Docs

The report is in `docs/main.pdf`. To rebuild it:

```bash
cd docs
build.bat
```

Needs a LaTeX distribution installed (like MiKTeX or TeX Live).
