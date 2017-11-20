pg_dump -Fc --no-owner --no-privileges pgsnapman > pgsnapman.cdmp
pg_dump -Fp --no-owner --no-privileges --schema-only pgsnapman > pgsnapman.sql

