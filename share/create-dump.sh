#!/bin/bash
pg_dump -Fc --no-owner --no-privileges pgsnapman > temp/pgsnapman.cdmp
pg_dump -Fp --no-owner --no-privileges --schema-only pgsnapman > share/pgsnapman.sql
exit $?

