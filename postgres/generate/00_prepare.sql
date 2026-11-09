-- =====================================================================
-- Préparation du générateur de données FICTIVES (aucune donnée réelle).
-- Paramètre psql : -v scale=1   (1 ≈ 5 Go en base, index compris ; linéaire)
-- Toutes les dérivations sont déterministes (fonctions SQL "inlinables"),
-- ce qui évite les jointures pendant la génération et la rend très rapide.
-- =====================================================================
CREATE SCHEMA IF NOT EXISTS gen;
CREATE SCHEMA IF NOT EXISTS bronze;

DROP TABLE IF EXISTS gen.params;
CREATE TABLE gen.params AS
SELECT
    :scale::numeric                              AS scale,
    greatest(1000, round(560000 * :scale))::bigint  AS n_pat,
    greatest(3000, round(1680000 * :scale))::bigint AS n_pas,
    1::bigint                                    AS batch_id;

-- Oppositions patient (vide au départ, alimentée par 50_increment.sql)
DROP TABLE IF EXISTS bronze.pat_opposition;
CREATE TABLE bronze.pat_opposition (
    pat_ipp          bigint      NOT NULL,
    date_opposition  date        NOT NULL,
    _batch_id        bigint      NOT NULL,
    _ingested_at     timestamptz NOT NULL DEFAULT now()
);

-- Patient (index 1..n_pat) d'un séjour : dispersion pseudo-aléatoire déterministe
CREATE OR REPLACE FUNCTION gen.pas_pat(p_pas bigint, p_n_pat bigint) RETURNS bigint
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$ SELECT 1 + ((p_pas * 7919) % p_n_pat) $$;

-- Type de séjour : CS (consultation), URG, HJ (hôpital de jour), HC (hospit. complète)
CREATE OR REPLACE FUNCTION gen.pas_type(p_pas bigint) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT CASE WHEN p_pas % 20 < 8  THEN 'CS'
              WHEN p_pas % 20 < 11 THEN 'URG'
              WHEN p_pas % 20 < 14 THEN 'HJ'
              ELSE 'HC' END $$;

-- Début de séjour entre 2018-01-01 et fin 2025
CREATE OR REPLACE FUNCTION gen.pas_start(p_pas bigint) RETURNS timestamp
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT timestamp '2018-01-01 00:00'
       + ((p_pas * 104729) % 2920) * interval '1 day'
       + ((p_pas * 37) % 24)        * interval '1 hour' $$;

-- Durée de séjour (jours) : 0 hors HC, 1..14 en HC
CREATE OR REPLACE FUNCTION gen.pas_los(p_pas bigint) RETURNS int
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT CASE WHEN p_pas % 20 < 14 THEN 0 ELSE 1 + ((p_pas * 31) % 14)::int END $$;

-- Fin de séjour (NULL = séjour HC encore en cours, ~0,1 %)
CREATE OR REPLACE FUNCTION gen.pas_end(p_pas bigint) RETURNS timestamp
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT CASE
           WHEN p_pas % 20 >= 14 AND p_pas % 997 = 0 THEN NULL
           ELSE gen.pas_start(p_pas)
              + gen.pas_los(p_pas) * interval '1 day'
              + (2 + (p_pas * 17) % 10) * interval '1 hour'
         END $$;

-- Unité fonctionnelle (UF) médicale du séjour
CREATE OR REPLACE FUNCTION gen.pas_uf(p_pas bigint) RETURNS int
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$ SELECT 1000 + ((p_pas * 13) % 120)::int $$;

-- ---------------------------------------------------------------------
-- Référentiel de mapping FICTIF (codes source -> concept_id LOCAUX > 2 000 000 000).
-- En réel : remplacer par les concepts standard Athena (source_to_concept_map / concept_relationship).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.ref_vocab_map;
CREATE TABLE bronze.ref_vocab_map (
    source_vocab      text     NOT NULL,   -- CIM10 | CCAM | BIO | UCD | UNIT | UF
    source_code       text     NOT NULL,
    source_label      text     NOT NULL,
    target_concept_id integer  NOT NULL,
    target_domain     text     NOT NULL,
    extra_num_1       numeric,             -- BIO : moyenne / UCD : dose usuelle
    extra_num_2       numeric,             -- BIO : écart-type
    extra_num_3       numeric,             -- BIO : borne basse
    extra_num_4       numeric,             -- BIO : borne haute
    extra_txt         text,                -- BIO : unité / UCD : voie
    _batch_id         bigint   NOT NULL DEFAULT 1,
    _ingested_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (source_vocab, source_code)
);

INSERT INTO bronze.ref_vocab_map
    (source_vocab, source_code, source_label, target_concept_id, target_domain)
SELECT 'CIM10', c, l, 2000000000 + row_number() OVER (), 'Condition'
FROM (VALUES
 ('I10','Hypertension essentielle'),('E11.9','Diabète de type 2 sans complication'),
 ('E78.0','Hypercholestérolémie pure'),('I48.9','Fibrillation auriculaire'),
 ('I50.9','Insuffisance cardiaque'),('I21.9','Infarctus du myocarde aigu'),
 ('I63.9','Infarctus cérébral'),('J44.9','BPCO'),('J45.9','Asthme'),
 ('J18.9','Pneumopathie'),('N18.3','Maladie rénale chronique stade 3'),
 ('N39.0','Infection urinaire'),('K80.2','Lithiase vésiculaire'),
 ('K35.8','Appendicite aiguë'),('C50.9','Tumeur maligne du sein'),
 ('C34.9','Tumeur maligne du poumon'),('C18.9','Tumeur maligne du côlon'),
 ('F32.9','Épisode dépressif'),('F20.9','Schizophrénie'),('F10.2','Dépendance à l''alcool'),
 ('G30.9','Maladie d''Alzheimer'),('G40.9','Épilepsie'),('M17.9','Gonarthrose'),
 ('M54.5','Lombalgie'),('S72.0','Fracture du col du fémur'),('S06.0','Commotion cérébrale'),
 ('O80','Accouchement unique spontané'),('Z38.0','Enfant unique né à l''hôpital'),
 ('D64.9','Anémie'),('E66.9','Obésité'),('E87.1','Hyponatrémie'),
 ('A41.9','Sepsis'),('U07.1','COVID-19'),('R07.4','Douleur thoracique'),
 ('R55','Syncope'),('Z51.1','Séance de chimiothérapie'),('Z49.1','Séance de dialyse'),
 ('K70.3','Cirrhose alcoolique'),('L03.1','Cellulite d''un membre'),('H25.9','Cataracte sénile')
) v(c, l);

INSERT INTO bronze.ref_vocab_map
    (source_vocab, source_code, source_label, target_concept_id, target_domain)
SELECT 'CCAM', c, l, 2000100000 + row_number() OVER (), 'Procedure'
FROM (VALUES
 ('XECG001','Électrocardiogramme (fictif)'),('XRAD001','Radiographie thorax (fictif)'),
 ('XSCA001','Scanner cérébral (fictif)'),('XIRM001','IRM rachis (fictif)'),
 ('XECH001','Échographie abdominale (fictif)'),('XEND001','Coloscopie (fictif)'),
 ('XEND002','Gastroscopie (fictif)'),('XCHI001','Appendicectomie (fictif)'),
 ('XCHI002','Cholécystectomie (fictif)'),('XCHI003','Prothèse de hanche (fictif)'),
 ('XCHI004','Prothèse de genou (fictif)'),('XCAR001','Coronarographie (fictif)'),
 ('XCAR002','Angioplastie coronaire (fictif)'),('XDIA001','Séance d''hémodialyse (fictif)'),
 ('XONC001','Séance de chimiothérapie (fictif)'),('XANE001','Anesthésie générale (fictif)'),
 ('XOPH001','Chirurgie de la cataracte (fictif)'),('XOBS001','Accouchement par voie basse (fictif)'),
 ('XOBS002','Césarienne (fictif)'),('XPNE001','Fibroscopie bronchique (fictif)'),
 ('XNEU001','EEG (fictif)'),('XURO001','Cystoscopie (fictif)'),
 ('XREA001','Ventilation mécanique (fictif)'),('XTRA001','Transfusion (fictif)'),
 ('XPON001','Ponction lombaire (fictif)')
) v(c, l);

INSERT INTO bronze.ref_vocab_map
    (source_vocab, source_code, source_label, target_concept_id, target_domain,
     extra_num_1, extra_num_2, extra_num_3, extra_num_4, extra_txt)
SELECT 'BIO', c, l, 2000200000 + row_number() OVER (), 'Measurement', m, s, lo, hi, u
FROM (VALUES
 ('GLY','Glycémie',5.5,1.8,3.9,6.1,'mmol/L'),('HBA1C','Hémoglobine glyquée',6.4,1.2,4.0,6.0,'%'),
 ('CREA','Créatinine',85,35,45,110,'µmol/L'),('HB','Hémoglobine',13.2,1.9,12.0,17.0,'g/dL'),
 ('LEUCO','Leucocytes',7.8,3.1,4.0,10.0,'G/L'),('PLAQ','Plaquettes',250,80,150,400,'G/L'),
 ('NA','Sodium',139,4,136,145,'mmol/L'),('K','Potassium',4.2,0.6,3.5,5.0,'mmol/L'),
 ('ALAT','ALAT',32,25,7,40,'UI/L'),('ASAT','ASAT',30,22,10,40,'UI/L'),
 ('CHOL','Cholestérol total',5.0,1.1,3.5,5.2,'mmol/L'),('CRP','Protéine C réactive',18,35,0,5,'mg/L'),
 ('TSH','TSH',2.1,1.4,0.4,4.0,'mUI/L'),('TG','Triglycérides',1.5,0.9,0.4,1.7,'mmol/L'),
 ('DFG','DFG estimé',78,24,60,120,'mL/min/1.73m2')
) v(c, l, m, s, lo, hi, u);

INSERT INTO bronze.ref_vocab_map
    (source_vocab, source_code, source_label, target_concept_id, target_domain, extra_num_1, extra_txt)
SELECT 'UCD', c, l, 2000300000 + row_number() OVER (), 'Drug', d, v
FROM (VALUES
 ('9000000000001','Paracétamol 1 g (fictif)',1000,'PO'),('9000000000002','Amoxicilline 1 g (fictif)',1000,'PO'),
 ('9000000000003','Énoxaparine 4000 UI (fictif)',4000,'SC'),('9000000000004','Furosémide 40 mg (fictif)',40,'PO'),
 ('9000000000005','Metformine 850 mg (fictif)',850,'PO'),('9000000000006','Insuline rapide (fictif)',10,'SC'),
 ('9000000000007','Amlodipine 5 mg (fictif)',5,'PO'),('9000000000008','Atorvastatine 20 mg (fictif)',20,'PO'),
 ('9000000000009','Bisoprolol 2,5 mg (fictif)',2.5,'PO'),('9000000000010','Oméprazole 20 mg (fictif)',20,'PO'),
 ('9000000000011','Morphine 10 mg (fictif)',10,'SC'),('9000000000012','Ceftriaxone 1 g (fictif)',1000,'IV'),
 ('9000000000013','NaCl 0,9 % 500 mL (fictif)',500,'IV'),('9000000000014','Apixaban 5 mg (fictif)',5,'PO'),
 ('9000000000015','Lévothyroxine 75 µg (fictif)',75,'PO'),('9000000000016','Sertraline 50 mg (fictif)',50,'PO'),
 ('9000000000017','Prednisolone 20 mg (fictif)',20,'PO'),('9000000000018','Salbutamol (fictif)',5,'INH'),
 ('9000000000019','Tramadol 50 mg (fictif)',50,'PO'),('9000000000020','Vancomycine 1 g (fictif)',1000,'IV')
) v(c, l, d, v);

INSERT INTO bronze.ref_vocab_map
    (source_vocab, source_code, source_label, target_concept_id, target_domain)
SELECT 'UF', (1000 + g)::text, 'UF fictive ' || (1000 + g), 2000400000 + g, 'CareSite'
FROM generate_series(0, 119) g;

ANALYZE bronze.ref_vocab_map;
