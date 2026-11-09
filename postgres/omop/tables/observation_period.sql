CREATE TABLE observation_period (
    observation_period_id          integer NOT NULL,
    person_id                      integer NOT NULL,
    observation_period_start_date  date    NOT NULL,
    observation_period_end_date    date    NOT NULL,
    period_type_concept_id         integer NOT NULL
);
