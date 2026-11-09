# Lab OMOP : Postgres (bronze) -> ClickHouse (silver/gold, dbt) -> Postgres (releases OMOP)
# Usage rapide :  make all        (tout, de zéro)   |   make help
ifeq ($(OS),Windows_NT)
# Windows (PowerShell/cmd) : utiliser Git Bash (le "bash" de Windows pointe vers WSL)
SHELL := C:/PROGRA~1/Git/bin/bash.exe
# Empêche Git Bash de convertir les chemins de conteneur (/lab/...) en chemins Windows
export MSYS_NO_PATHCONV := 1
else
SHELL := /bin/bash
endif
include .env
export

DC := docker compose

.PHONY: help up down ps logs generate increment dbt dbt-full dbt-test publish rollback bench all ui clean

help: ## Affiche cette aide
	@grep -hE '^[a-zA-Z_-]+:.*?## ' Makefile | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}'

up: ## Démarre Postgres, ClickHouse, CH-UI et Grafana
	$(DC) up -d postgres clickhouse ch-ui grafana
	$(DC) build dbt

down: ## Arrête les services (données conservées)
	$(DC) down

ps: ## État des services
	$(DC) ps

logs: ## Logs ClickHouse et Postgres
	$(DC) logs --tail=100 clickhouse postgres

generate: ## Génère le bronze fictif (SCALE=1 ≈ 5 Go ; ex. make generate SCALE=0.1)
	$(SHELL) ./scripts/generate_data.sh $(SCALE)

increment: ## Simule un nouveau lot d'ingestion (nouveaux séjours, corrections, oppositions)
	$(SHELL) ./scripts/simulate_batch.sh

dbt: ## dbt build incrémental (bronze -> silver -> gold + tests)
	$(DC) run --rm dbt build

dbt-full: ## dbt build complet (reconstruit tout)
	$(DC) run --rm dbt build --full-refresh

dbt-test: ## Tests dbt uniquement
	$(DC) run --rm dbt test

publish: ## Publie une release OMOP figée dans Postgres (schéma cdm, bascule atomique)
	$(SHELL) ./scripts/publish_omop_release.sh

rollback: ## Revient à la release OMOP précédente
	$(SHELL) ./scripts/rollback_omop_release.sh

bench: ## Benchmark Postgres (cdm) vs ClickHouse (gold_omop) sur les mêmes données
	$(SHELL) ./scripts/benchmark.sh

all: up generate dbt publish bench ui ## Tout enchaîner de zéro

ui: ## Rappelle les adresses des interfaces
	@echo "CH-UI      : http://localhost:3488   (utilisateur: lecteur / mot de passe: $(CH_READER_UI_PASSWORD))"
	@echo "Console CH : http://localhost:8123/play   |   Tableau de bord CH : http://localhost:8123/dashboard"
	@echo "Grafana    : http://localhost:3000   (admin / $(GRAFANA_ADMIN_PASSWORD)) -> dossier 'Lab OMOP'"
	@echo "Postgres   : localhost:$(PG_PORT)  bases eds (bronze) et omop (schéma cdm)  user $(PG_USER)"

clean: ## Supprime conteneurs ET volumes (toutes les données)
	$(DC) down -v
