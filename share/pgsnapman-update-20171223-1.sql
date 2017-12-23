-- allow LEAVE as value in job restore defintion
alter table pgsnap_restorejob drop constraint "pgsnap_restorejob_existing_db_check";
alter table pgsnap_restorejob add check (existing_db = ANY (ARRAY['DROP'::text, 'RENAME'::text, 'DROP_BEFORE'::text, 'LEAVE'::text]));

