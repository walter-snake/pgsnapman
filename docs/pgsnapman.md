# PgSnapMan

## Contents

* [What and why](pgsnapman.md)
* [User manual](manual.md)
* [Reference documentation](reference.md)

## What and why

PgSnapMan is a dump and restore management system for Postgres. The purpose of a dump is, besides obviously safeguarding data, also copying and distributing data, as well as server migration. Safeguarding is easy: just make a dump of every available database, and store them, forget about them and leave it to a specialist to rescue a database when neccessary. We don't need a dump and restore management system for this task.

But, if you need to regularly copy databases between development, testing and production environments, or distribute datasets between servers in a scenario where streaming replication is not the appropriate solution (and there are many of such cases), you'll want to have a system in place to manage your dumps and restores. Especially if more general IT personnel has to perform most of the tasks. We also have to deal with storage space, which is typically not unlimited.

After looking around for software that does the job, I encountered ['PgBackMan'](https://e-mc2.net/pgbackman) by the University of Oslo, a pretty nice solution but it didn't meet enough of my requirements and it has some drawbacks for specific set-ups, which left me the job of creating my own. Wise decision? Check it out...

### The top reasons to use PgSnapMan

* scheduled dumps don't rely on any service or database
* deals nicely with partial dump/restore, roles, tablespaces and database/schema creation
* scheduled replication to multiple targets
* space saving: built-in deduplication of table data files
* automatic verification of the dumps
* detailed clean up schedule (retention policy)
* easy to use manager application

### About the name

PgBackMan was already occupied, 'dumpman' sounds too much like 'dumb' man (may be I am), so I decided that 'snap' man was not too bad, as these dumps are actually snapshots.

## Other great backup and protection tools
* PgBackMan, comparable but substantially different to PgSnapMan: ['PgBackMan'](https://e-mc2.net/pgbackman)
* RepMgr, replication manager for streaming replication and fail-over: ['RepMgr'](https://repmgr.org/)
* Barman, Point In Time Recovery management: ['Barman'](http://www.pgbarman.org/)

