-- DQD reads the CDM metadata from cdm_source, so make sure it has a row
INSERT INTO public.cdm_source (
    cdm_source_name, cdm_source_abbreviation, cdm_holder, source_description,
    source_release_date, cdm_release_date, cdm_version, cdm_version_concept_id, vocabulary_version
)
SELECT 'OMOP CDM', 'OMOP', 'Local', 'Empty OMOP CDM database',
       current_date, current_date, 'v5.4', 756265,
       coalesce((SELECT vocabulary_version FROM public.vocabulary WHERE vocabulary_id = 'None'), 'unknown')
WHERE NOT EXISTS (SELECT 1 FROM public.cdm_source);
