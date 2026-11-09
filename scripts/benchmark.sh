#!/usr/bin/env bash
# =====================================================================
# Benchmark équitable : MÊMES données OMOP, MÊMES questions.
#   PostgreSQL : schéma cdm (dernière release publiée, avec index OHDSI)
#   ClickHouse : gold_omop (FINAL + _is_deleted = 0, comme en production)
# Chaque requête est lancée RUNS fois ; on garde le meilleur temps (cache chaud).
# Résultat : tableau Markdown affiché + enregistré dans results/.
# =====================================================================
source "$(dirname "$0")/lib.sh"

PG_DB_OMOP="${PG_DB_OMOP:-omop}"
RUNS="${RUNS:-3}"
mkdir -p results
OUT="results/benchmark_$(date +%Y%m%d_%H%M%S).md"

# Concepts ciblés, lus dans le dictionnaire ClickHouse (mêmes identifiants des deux côtés)
cid() { ch_query "SELECT dictGet('silver.dict_vocab', 'target_concept_id', tuple('$1', '$2'))"; }
C_DIAB=$(cid CIM10 E11.9); C_HBA1C=$(cid BIO HBA1C); C_CREA=$(cid BIO CREA)
[[ -n "$C_DIAB" && -n "$C_HBA1C" && -n "$C_CREA" ]] || die "concepts introuvables (dbt build lancé ?)"
P_ID="${BENCH_PERSON_ID:-1234}"

declare -a NAMES PGQ CHQ
add() { NAMES+=("$1"); PGQ+=("$2"); CHQ+=("$3"); }

add "Biologie : volume et moyenne par analyse et année" \
"SELECT measurement_concept_id, extract(year FROM measurement_date) AS y, count(*), avg(value_as_number)
 FROM cdm.measurement GROUP BY 1, 2" \
"SELECT measurement_concept_id, toYear(measurement_date) AS y, count(), avg(value_as_number)
 FROM gold_omop.measurement FINAL WHERE _is_deleted = 0 GROUP BY 1, 2"

add "Top 10 diagnostics (patients distincts)" \
"SELECT condition_concept_id, count(DISTINCT person_id) AS n
 FROM cdm.condition_occurrence GROUP BY 1 ORDER BY 2 DESC LIMIT 10" \
"SELECT condition_concept_id, uniqExact(person_id) AS n
 FROM gold_omop.condition_occurrence FINAL WHERE _is_deleted = 0 GROUP BY 1 ORDER BY 2 DESC LIMIT 10"

add "Cohorte : diabète (E11.9) + HbA1c > 7 au même séjour" \
"SELECT count(DISTINCT c.person_id)
 FROM cdm.condition_occurrence c
 JOIN cdm.measurement m ON m.visit_occurrence_id = c.visit_occurrence_id
 WHERE c.condition_concept_id = $C_DIAB
   AND m.measurement_concept_id = $C_HBA1C AND m.value_as_number > 7" \
"SELECT uniqExact(c.person_id)
 FROM (SELECT person_id, visit_occurrence_id FROM gold_omop.condition_occurrence FINAL
       WHERE _is_deleted = 0 AND condition_concept_id = $C_DIAB) c
 INNER JOIN (SELECT visit_occurrence_id FROM gold_omop.measurement FINAL
             WHERE _is_deleted = 0 AND measurement_concept_id = $C_HBA1C AND value_as_number > 7) m
 ON m.visit_occurrence_id = c.visit_occurrence_id"

add "Créatinine mensuelle des plus de 75 ans (jointure person)" \
"SELECT date_trunc('month', m.measurement_date) AS mois, avg(m.value_as_number), count(*)
 FROM cdm.measurement m JOIN cdm.person p USING (person_id)
 WHERE m.measurement_concept_id = $C_CREA
   AND extract(year FROM m.measurement_date) - p.year_of_birth > 75
 GROUP BY 1" \
"SELECT toStartOfMonth(m.measurement_date) AS mois, avg(m.value_as_number), count()
 FROM (SELECT person_id, measurement_date, value_as_number FROM gold_omop.measurement FINAL
       WHERE _is_deleted = 0 AND measurement_concept_id = $C_CREA) m
 INNER JOIN (SELECT person_id, year_of_birth FROM gold_omop.person FINAL WHERE _is_deleted = 0) p
 USING (person_id)
 WHERE toYear(m.measurement_date) - p.year_of_birth > 75
 GROUP BY mois"

add "Activité par UF et par mois (visites, patients distincts)" \
"SELECT care_site_id, date_trunc('month', visit_start_date), count(*), count(DISTINCT person_id)
 FROM cdm.visit_occurrence GROUP BY 1, 2" \
"SELECT care_site_id, toStartOfMonth(visit_start_date), count(), uniqExact(person_id)
 FROM gold_omop.visit_occurrence FINAL WHERE _is_deleted = 0 GROUP BY 1, 2"

add "Prescriptions : durée moyenne par médicament et voie" \
"SELECT drug_source_value, route_source_value, count(*), avg(days_supply)
 FROM cdm.drug_exposure GROUP BY 1, 2" \
"SELECT drug_source_value, route_source_value, count(), avg(days_supply)
 FROM gold_omop.drug_exposure FINAL WHERE _is_deleted = 0 GROUP BY 1, 2"

add "Parcours d'un patient : toute sa biologie (accès ponctuel)" \
"SELECT measurement_date, measurement_concept_id, value_as_number
 FROM cdm.measurement WHERE person_id = $P_ID ORDER BY measurement_date" \
"SELECT measurement_date, measurement_concept_id, value_as_number
 FROM gold_omop.measurement FINAL WHERE _is_deleted = 0 AND person_id = $P_ID ORDER BY measurement_date"

pg_time_ms() {   # meilleur temps (ms) côté serveur, résultat jeté
  local sql="$1" best=""
  for _ in $(seq "$RUNS"); do
    t=$(printf '\\timing on\n\\o /dev/null\n%s;\n' "$sql" | psql_db "$PG_DB_OMOP" | sed -n 's/^Time: \([0-9.]*\) ms.*/\1/p' | tail -1)
    [[ -z "$best" ]] || awk -v a="$t" -v b="$best" 'BEGIN{exit !(a<b)}' && best="$t"
  done
  echo "$best"
}

ch_time_ms() {   # meilleur temps (ms) ; FORMAT Null = pas de transfert de résultat
  local sql="$1" best=""
  for _ in $(seq "$RUNS"); do
    t=$(printf '%s FORMAT Null' "$sql" | curl -sS --fail-with-body -o /dev/null -w '%{time_total}' \
          -H "X-ClickHouse-User: ${CH_USER}" -H "X-ClickHouse-Key: ${CH_PASSWORD}" \
          --data-binary @- "${CH_URL}/" | awk '{printf "%.1f", $1 * 1000}')
    [[ -z "$best" ]] || awk -v a="$t" -v b="$best" 'BEGIN{exit !(a<b)}' && best="$t"
  done
  echo "$best"
}

pg_rows=$(psql_db "$PG_DB_OMOP" -tA -c "SELECT count(*) FROM cdm.measurement")
{
  echo "# Benchmark OMOP — PostgreSQL vs ClickHouse ($(date '+%Y-%m-%d %H:%M'))"
  echo
  echo "Volume : ${pg_rows} lignes dans measurement. Meilleur temps sur ${RUNS} exécutions."
  echo
  echo "| Requête | PostgreSQL (ms) | ClickHouse (ms) | Gain |"
  echo "|---|---:|---:|---:|"
} | tee "$OUT"

for i in "${!NAMES[@]}"; do
  log "Requête $((i + 1))/${#NAMES[@]} : ${NAMES[$i]}"
  p=$(pg_time_ms "${PGQ[$i]}")
  c=$(ch_time_ms "${CHQ[$i]}")
  g=$(awk -v p="$p" -v c="$c" 'BEGIN{ if (c > 0) printf "×%.1f", p / c; else print "-" }')
  echo "| ${NAMES[$i]} | ${p} | ${c} | ${g} |" | tee -a "$OUT"
done

echo | tee -a "$OUT"
echo "_ClickHouse inclut le coût de FINAL (lecture dédupliquée). Temps ClickHouse mesurés côté client HTTP (latence locale incluse)._" | tee -a "$OUT"
log "Résultats enregistrés dans $OUT"
