#! /bin/env/python

# PgSnapMan manager: list, upload, delete postgres instances, workers, jobs catalog entries

import psycopg2
from psycopg2 import extras
import sys
import os
import ConfigParser
import getpass
from prettytable import PrettyTable
from prettytable import from_db_cursor
  
def listDbView(viewname, title, search = 'true'):
  if search.find(';') >= 0:
    print('WARNING: invalid filter, has been reset')
    search='true'
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  cur.execute('SELECT * FROM ' + viewname + ' WHERE ' + search + ';')
  print('')
  print(title)
  if not search == 'true':
    print('')
    print('Filter: ' + search)
    print('')
  t = from_db_cursor(cur)
  t.align = 'l'
  print t
  #table = t.get_string(print_empty=False)
  #print table.replace('None', '    ')
  conn.commit()
  conn.close()
  print('')

def listDetails(tablename, id, title):
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
  cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
  cur.execute('SELECT * FROM ' + tablename + ' WHERE id = %s;', (id, ))
  rec = cur.fetchone()
  colnames = [desc[0] for desc in cur.description]
  print ''
  print title
  print ''.ljust(48, '-')
  for c in colnames:
    print(c.ljust(26) + str(rec[c]))
  print ''

def setTableColumn(tablename, column, id, value, showresults = False):
  if column.find(';') >= 0:
    print 'invalid column name'
    return
  setnull=False
  if value == None:
    sql = "update {} set {} = null where id = %s;".format(tablename, column)
    setnull = True
  elif str(value).strip() == '':
    sql = "update {} set {} = null where id = %s;".format(tablename, column)
    setnull = True
  else:
    sql = "update {} set {} = %s where id = %s;".format(tablename, column)
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
  cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
  try:
    if setnull:
      cur.execute(sql, (id ,))
    else:
      cur.execute(sql, (value, id ,))
  except psycopg2.Error as e:
    print e.pgerror
  conn.commit()
  conn.close()
  if showresults:
    listDetails(tablename, id, 'Verify update results')

def editRecord(tablename, id, editcols):
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
  cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
  sql = 'select * from ' + tablename + ' where id = %s;'
  cur.execute(sql, (id ,))
  row=cur.fetchone()
  conn.close()
  listDetails(tablename, id, 'Current record: {} [{}]'.format(tablename, id))
  print('Enter new values:')
  print('  (use exactly one space to clear a field):')
  print ''.ljust(48, '-')
  for c in editcols:
    if row[c] == None:
      dispval = ''
    else:
      dispval = row[c]
    newval = raw_input(('{} [{}]'.format(c, dispval)).ljust(40, ' ') + ': ')
    if newval == ' ':
      row[c] = ''
    elif newval.strip() != '':
      row[c] = newval.strip()
  print('')
  print('Review new values:')
  print ''.ljust(48, '-')
  for c in editcols:
    print('{}'.format(c).ljust(26, ' ') + str(row[c]))
  yn = raw_input('Save new values [yN]? ')
  if yn == 'y':
    for c in editcols:
      setTableColumn(tablename, c, id, row[c])
    listDetails(tablename, id, 'Verify update results')
  print('')
  
def getPgsqlInstanceId(pgdns, pgport):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'select * from get_pgsql_instance_id(%s, %s)'
    cur.execute(sql, (pgdns, pgport))
    row=cur.fetchone()
    conn.close()
    return row[0]

def getDefaultWorkerId(pgid):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'select * from get_defaultworker(%s)'
    cur.execute(sql, (pgid, ))
    row=cur.fetchone()
    conn.close()
    return row[0]

def getCatalogIdExists(catid):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'select * from get_catalogidexists(%s)'
    cur.execute(sql, (catid, ))
    row=cur.fetchone()
    conn.close()
    return row[0]

def getRndCron(pgid):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'select * from get_rndcron(%s)'
    cur.execute(sql, (pgid, ))
    row=cur.fetchone()
    conn.close()
    return row[0]

def insertWorker(dns_name, cron_cacheconfig, cron_singlejob, cron_clean, cron_upload, comment):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'insert into pgsnap_worker (dns_name, cron_cacheconfig, cron_singlejob, cron_clean, cron_upload, comment) VALUES (%s, %s, %s, %s, %s, %s) returning id;'
    cur.execute(sql, (dns_name, cron_cacheconfig, cron_singlejob, cron_clean, cron_upload, comment))
    row = cur.fetchone()
    print('-> Registered worker instance with id: {}'.format(row[0]))
    conn.commit()
    conn.close()
    return row[0]

def insertInstance(dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'insert into pgsql_instance (dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment) VALUES (%s, %s, %s, %s, %s, %s, %s) returning id;'
    cur.execute(sql, (dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment))
    row = cur.fetchone()
    print('-> Registered postgres instance with id: {}'.format(row[0]))
    conn.commit()
    conn.close()
    return row[0]
    
def insertDumpJob(pgsnap_worker_id, pgsql_instance_id, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, pgsnap_restorejob_id):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'insert into pgsnap_dumpjob (pgsnap_worker_id, pgsql_instance_id, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, pgsnap_restorejob_id) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) returning id;'
    cur.execute(sql, (pgsnap_worker_id, pgsql_instance_id, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, pgsnap_restorejob_id))
    row = cur.fetchone()
    print('-> Created dump job with id: {}'.format(row[0]))
    conn.commit()
    conn.close()
    return row[0]
    
#    dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, status, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling
def insertRestoreJob(dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'insert into pgsnap_restorejob (dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) returning id;'
    cur.execute(sql, (dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling))
    row = cur.fetchone()
    print('-> Created restore job with id: {}'.format(row[0]))
    conn.commit()
    conn.close()
    return row[0]
    
    
def deleteFromDb(tablename, id):
    if not tablename in ['pgsnap_dumpjob', 'pgsnap_worker', 'pgsql_instance', 'pgsnap_restorejob']:
      print 'table name not valid'
      return
    yn = raw_input('Do you really want to delete {}.{}? [yN] '.format(tablename, id))
    if not yn.lower() == 'y':
      return    
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'delete from {} where id = %s'.format(tablename)
    cur.execute(sql, (id, ))
    conn.commit()
    conn.close()
    print('-> Deleted: {} [{}]'.format(tablename, id))
  
def getInput(message, values, defval, width = 32, allowempty = True):
  ri = ''
  while ri not in values or len(values) == 1 or ri in ['?', '']:
    ri = raw_input('{} [{}]'.format(message, defval).ljust(width, ' ') + ': ')
    if ri == '?':
      print '  ' + values[0]
      for i in range(1, len(values)):
        print('    ' + str(values[i]))
    elif ri == '':
      if allowempty:
        return ''
      else:
        if not defval == '':
          return defval
    elif ri == ' ':
      return ''
    else:
      if ri in values or len(values) == 1:
        return ri

# register worker
def registerWorker():
  print('')
  print('Register a pgsnapman worker, enter values (list of options/help tekst: ?):')
  dns_name = getInput('worker dns name:', ['dns name as reported by hostname -f or name set in worker config'], '', 54, False)
  cron_cacheconfig = getInput('cache refresh cron:', ['numeric cron entry'], '0 */2 * * *', 54, False)
  cron_singlejob = getInput('single run check cron:', ['numeric cron entry'], '* * * * *', 54, False)
  cron_clean = getInput('cleaning up cron:', ['numeric cron entry'], '0 8 * * *', 54, False)
  cron_upload = getInput('cache refresh cron:', ['numeric cron entry'], '*/5 * * * *', 54, False)
  comment = getInput('comment', ['optional comments'], '', 54)
  yn = raw_input('Save new worker? [Yn] ')
  if not yn.lower() == 'n':
    id = insertWorker(dns_name, cron_cacheconfig, cron_singlejob, cron_clean, cron_upload, comment)
    listDetails('pgsnap_worker', id, 'Verify worker details')
    print('')
    yn = raw_input('Do you want to edit the worker? [yN] ')
    if yn.lower() == 'y':
      editRecord('pgsnap_worker', id, ['status', 'cron_cacheconfig', 'cron_singlejob', 'cron_clean', 'cron_upload', 'comment'])
  print('')

# register instance
def registerInstance():
  print('')
  print('Register a postgres instance, enter values (list of options/help tekst: ?):')
  dns_name = getInput('postgres instance dns name:', ['fqdn dns name'], '', 54, False)
  pgport = getInput('postgres port:', ['port number'], '5432', 54, False)
  pgsql_superuser = getInput('postgres superuser', ['postgres super user'], 'postgres', 54, False)
  bu_window_start = getInput('backup window start hour:', range(0,24), '20', 54, False)
  bu_window_end = getInput('backup window end hour:', range(0,24), '6', 54, False)
  pgsnap_worker_id_default = getInput('default pgsnapman worker', ['id of an existing worker'], '', 54, False)
  comment = getInput('comment', ['optional comments'], '', 54)
  yn = raw_input('Save new instance? [Yn] ')
  if not yn.lower() == 'n':
    id = insertInstance(dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment)
    listDetails('pgsql_instance', id, 'Verify instance details')
    print('')
    yn = raw_input('Do you want to edit the instance? [yN] ')
    if yn.lower() == 'y':
      editRecord('pgsql_instance', id, ['status', 'pgsql_superuser', 'bu_window_start', 'bu_window_end', 'pgsnap_worker_id_default', 'comment'])
  print('')

# add dump job
def addDumpJob():
  print('')
  print('Add a dump job, enter values (list of options/help tekst: ?):')
  jobtype = getInput('job type', ['choose one from', 'SINGLE', 'REPEAT'], 'SINGLE', 54, False)
  pgdns = getInput('postgres dns name', ['dns name of the source postgres server'], '', 54, False)
  pgport = getInput('postgres port', ['port number'], '5432', 54, False)
  pgsqlid = getPgsqlInstanceId(pgdns, pgport)
  if pgsqlid == '' or pgsqlid == None:
    print('ERROR: postgres instance not available')
    return
  else:
    print('  -> postgres instance id set [{}]'.format(pgsqlid))
  workerid = getDefaultWorkerId(pgsqlid)
  print('  -> worker id set [{}]'.format(workerid))
  dbname = getInput('database name', ['database name'], '', 54, False)
  dumpschema = getInput('schema name', ['dump specific schema or all (*)'], '*', 54, False)
  dumpoptions = getInput('additional options', ['regular pg_dump(all) options'], '', 54)
  dumptype = getInput('dump type', ['choose one from; SCHEMA is structure in this context','FULL','SCHEMA','DATA','CLUSTER','CLUSTER_SCHEMA'], 'FULL', 54, False)
  if jobtype == 'SINGLE':
    runwhen = getInput('run once at', ['cron schedule (NOW: as soon as possible)', 'NOW', 'numeric cron entry'], 'NOW', 54, False)
    if runwhen == 'NOW':
      cron = '* * * * *'
  else:
    runwhen = getInput('repeat schedule', ['cron schedule (numeric)'], getRndCron(pgsqlid), 54, False)
    cron = runwhen
  comment = getInput('comment', ['optional comments'], '', 54)
  yn = raw_input('Save new job? [Yn] ')
  if not yn.lower() == 'n':
    id = insertDumpJob(workerid, pgsqlid, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, None)
    listDetails('pgsnap_dumpjob', id, 'Verify job details')
    print('')
    yn = raw_input('Do you want to edit the job? [yN] ')
    if yn.lower() == 'y':
      editRecord('pgsnap_dumpjob', id, ['cron', 'dumpoptions', 'status', 'dumptype', 'comment'])
  print('')

# add restore job
def addRestoreJob():
  print('')
  print('Add a restore job, enter values (list of options/help tekst: ?):')
  jobtype = getInput('job type', ['choose one from', 'SINGLE', 'REPEAT', 'TRIGGER'], 'SINGLE', 54, False)
  if jobtype == 'TRIGGER':
    pgsnap_catalog_id = ''
  else:
    pgsnap_catalog_id = getInput('restore from catalog id', ['catalog id'], '', 54, False)
    if not getCatalogIdExists(pgsnap_catalog_id):
      print('catalog id not found')
      return    
  pgdns = getInput('postgres dns name', ['full dns name of the destination postgres server'], '', 54, False)
  pgport = getInput('postgres port', ['postgres instance port number'], '5432', 54, False)
  dest_pgsql_instance_id = getPgsqlInstanceId(pgdns, pgport)
  if dest_pgsql_instance_id == '' or dest_pgsql_instance_id == None:
    print('ERROR: postgres instance not available')
    return
  else:
    print('  -> postgres instance id set [{}]'.format(dest_pgsql_instance_id))
  dest_dbname = getInput('destination database', ['name of the destination database'], '', 54, False)
  restoreschema = getInput('restore schema', ['restore specific schema or all (*)'], '*', 54, False)
  restoreoptions = getInput('additional options', ['regular pg_restore(all) options; N/A for a CLUSTER* restore'], '', 54)  
  restoretype = getInput('restore type (N/A for a CLUSTER* restore)', ['type of restore; SCHEMA is structure in this context; N/A for a CLUSTER* restore','FULL','SCHEMA','DATA'], 'FULL', 54, False)
  existing_db = getInput('handling of existing database', ['drop or rename an existing database; DROP_BEFORE drops before attempting to restore', 'DROP', 'RENAME', 'DROP_BEFORE'], 'RENAME', 54, False)
  if jobtype == 'SINGLE':
    runwhen = getInput('run once at', ['cron schedule (NOW: as soon as possible)', 'NOW', 'numeric cron entry'], 'NOW', 54, False)
    if runwhen == 'NOW':
      cron = '* * * * *'
  elif jobtype == 'TRIGGER':
    cron = '* * * * *'
  else:
    runwhen = getInput('repeat schedule', ['cron schedule (numeric)'], getRndCron(pgsqlid), 54, False)
    cron = runwhen
  role_handling = getInput('handling of roles', ['tries to create required roles or ignore are role related information', 'USE_ROLE', 'NO_ROLE'], 'USE_ROLE', 54, False)
  tblspc_handling = getInput('handling of existing database', ['tries to restore into the correct tablespaces (must be present) or restore to default', 'NO_TBLSPC', 'USE_TBLSPC'], 'NO_TBLSPC', 54, False)
  comment = getInput('comment', ['optional comments'], '', 54)
  yn = raw_input('Save new job? [Yn] ')
  if not yn.lower() == 'n':
    id = insertRestoreJob(dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling)
    listDetails('pgsnap_restorejob', id, 'Verify job details')
    print('')
    yn = raw_input('Do you want to edit the job? [yN] ')
    if yn.lower() == 'y':
      editRecord('pgsnap_restorejob', id, ['dest_pgsql_instance_id', 'cron', 'restoreoptions', 'status', 'restoretype', 'role_handling', 'tblspc_handling', 'comment'])
  print('')

def showHeader():
  print """
+--------------------------------------------------+
|                                                  |
|                PgSnapMan manager                 |
|                                                  |
| W.Boasson, 2017                                  |
| License: GPL3                                    |
|                                                  |
+--------------------------------------------------+
"""

def showHelp():
  print """
Available commands
==================

* The group may be abbreviated to one letter.
* Choice:       [choice1|choice2|...]
* Optional:     {}
* Full details: +<id>

It is also possible to enter the commands directly on the command line
when calling pgs-manager.

worker management
-----------------
  worker list
  worker list+<id>
  worker register
  worker status [ACTIVE|HALTED]
  worker edit <id>
  worker delete <id>
  
postgres management
-------------------
  postgres list
  postgres list+<id>
  postgres register
  postgres status [ACTIVE|HALTED]
  postgres edit <id>
  postgres delete <id>

catalog management
------------------
  catalog list
  catalog list+<id>
  catalog search "<filter>"  
    <filter>: regular Postgres filter, you may filter on every
              column available in the view; for security reasons
              using a ; is not allowed
  catalog keep [NO|YES|AUTO]

dump job management
-------------------
  dumpjob list
  dumpjob list+<id>
  dumpjob add
  dumpjob status [ACTIVE|HALTED]
  dumbjob edit <id>
  dumbjob delete <id>

restore job management
----------------------
  restorejob list
  restorejob list+<id>
  restorejob add
  restorejob status [ACTIVE|HALTED]
  restorejob edit <id>
  restorejob delete <id>

log of restore jobs
-------------------
  log-restore list
  log-restore list+<id>
  log-restore search <filter>
    <filter>: regular Postgres filter, you may filter on every
              column available in the view; for security reasons
              using a ; is not allowed
  log-restore <status>
    <status>: Warning, Error, Completed
  
messages
--------
  message list
  message list+<id>
  log-restore search <filter>
    <filter>: regular Postgres filter, you may filter on every
              column available in the view; for security reasons
              using a ; is not allowed
  message <status>
    <status>: Debug, Info, Warning, Error, Critical
  """  

def workerTask(task):
  t = task.split(' ')[1][:1]
  if t == 'l':
    if '+' in task:
      listDetails('pgsnap_worker', task.split('+')[1].strip(), 'PgSnapMan worker details')
    else:
      listDbView('mgr_worker', 'Registered PgSnapMan workers')
  elif t == 's': # set status
    tokens = task.split(' ')
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsnap_worker', 'status', id, status, True)
  elif t == 'e': # edit record
    tokens = task.split(' ')
    id = tokens[2]
    editRecord('pgsnap_worker', id, ['status', 'cron_cacheconfig', 'cron_singlejob', 'cron_clean', 'cron_upload', 'comment'])
  elif t == 'r': # register worker   
    registerWorker()
  elif t == 'x': # delete worker
    tokens = task.split(' ')
    id = tokens[2]
    deleteFromDb('pgsnap_worker', id)

def instanceTask(task):
  t = task.split(' ')[1][:1]
  if t == 'l':
    if '+' in task:
      listDetails('pgsql_instance', task.split('+')[1].strip(), 'Postgres instance details')
    else:
      listDbView('mgr_instance', 'Registered Postgres instances')
  elif t == 's': # set status
    tokens = task.split(' ')
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsql_instance', 'status', id, status, True)
  elif t == 'e': # edit record
    tokens = task.split(' ')
    id = tokens[2]
    editRecord('pgsql_instance', id, ['status', 'pgsql_superuser', 'bu_window_start', 'bu_window_end', 'pgsnap_worker_id_default', 'comment'])
  elif t == 'r': # register instance
    registerInstance()
  elif t == 'x': # delete instance
    tokens = task.split(' ')
    id = tokens[2]
    deleteFromDb('pgsql_instance', id)

def dumpjobTask(task):
  t = task.split(' ')[1][:1]
  if t == 'l':
    if '+' in task:
      listDetails('pgsnap_dumpjob', task.split('+')[1].strip(), 'Dump job details')
    else:
      listDbView('mgr_dumpjob', 'Dump jobs')
  elif t == 's': # set status
    tokens = task.split(' ')
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsnap_dumpjob', 'status', id, status, True)
  elif t == 'e': # edit record
    tokens = task.split(' ')
    id = tokens[2]
    editRecord('pgsnap_dumpjob', id, ['cron', 'dumpoptions', 'status', 'dumptype'])
  elif t == 'a': # add dumpjob    
    addDumpJob()
  elif t == 'x': # delete dumpjob
    tokens = task.split(' ')
    id = tokens[2]
    deleteFromDb('pgsnap_dumpjob', id)

def restorejobTask(task):
  t = task.split(' ')[1][:1]
  if t == 'l':
    if '+' in task:
      listDetails('pgsnap_restorejob', task.split('+')[1].strip(), 'Restore job details')
    else:
      listDbView('mgr_restorejob', 'Restore jobs')
  elif t == 's': # set status
    tokens = task.split(' ')
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsnap_restorejob', 'status', id, status, True)
  elif t == 'e': # edit record
    tokens = task.split(' ')
    id = tokens[2]
    editRecord('pgsnap_restorejob', id, ['dest_pgsql_instance_id', 'cron', 'restoreoptions', 'status', 'restoretype', 'role_handling',  'tblspc_handling', 'comment'])
  elif t == 'a': # add restorejob    
    addRestoreJob()
  elif t == 'x': # delete restorejob
    tokens = task.split(' ')
    id = tokens[2]
    deleteFromDb('pgsnap_restorejob', id)
  
def catalogTask(task):
  t = task.split(' ')[1][:1]
  if t == 'l':
    if '+' in task:
      listDetails('pgsnap_catalog', task.split('+')[1].strip(), 'Backup details')
    else:
      listDbView('mgr_catalog', 'Available backups')
  elif t == 's': # search task
    tokens = task.split(' ')
    search=''
    for tok in range(2, len(tokens)):
      search = search + ' ' + tokens[tok]
    listDbView('mgr_catalog', 'Available backups', search.strip())
  elif t == 'j': # search task
    search = "split_part(jobid_dbname, '/', 1) ilike '{}'".format(task.split(' ')[2])
    listDbView('mgr_catalog', 'Available backups', search.strip())
  elif t == 'd': # search task
    search = "split_part(jobid_dbname, '/', 2) ilike '{}.%'".format(task.split(' ')[2])
    listDbView('mgr_catalog', 'Available backups', search.strip())
  elif t == 'k': # set keep status
    tokens = task.split(' ')
    id = tokens[2]
    col = tokens[3]
    val = tokens[4]
    setTableColumn('pgsnap_catalog', col, id, val, True)

def restorelogTask(task):
  t = task.split(' ')[1][:1]
  if t == 'l': # results: the restore log
    if '+' in task:
      listDetails('pgsnap_restorelog', task.split('+')[1].strip(), 'Restore log details')
    else:
      listDbView('mgr_restorelog', 'Restore jobs log')
  elif t == 'j': # search task
    search = "split_part(jobid_dbname, '/', 1) ilike '{}'".format(task.split(' ')[2])
    listDbView('mgr_restorelog', 'Restore log', search.strip())
  elif t == 'd': # search task
    search = "split_part(jobid_dbname, '/', 2) ilike '{}.%'".format(task.split(' ')[2])
    listDbView('mgr_restorelog', 'Restore log', search.strip())
  elif t == 's': # search task
    tokens = task.split(' ')
    search=''
    for tok in range(2, len(tokens)):
      search = search + ' ' + tokens[tok]
    listDbView('mgr_restorelog', 'Restore jobs log', search.strip())
  else: # letter corresponds to an error level
    if t.lower() in ['e', 'i', 'c', 'd', 'w']:
      listDbView('mgr_restorelog', 'Restore jobs log', "status ilike '{}%'".format(t[:1]))
    else:
      print('Invalid message level specified')
    
def messageTask(task):
  t = task.split(' ')[1][:1]
  if t == 'l':
    if '+' in task:
      listDetails('pgsnap_message', task.split('+')[1].strip(), 'Message details')
    else:
      listDbView('mgr_message', 'General message log')
  elif t == 's': # search task
    tokens = task.split(' ')
    search=''
    for tok in range(2, len(tokens)):
      search = search + ' ' + tokens[tok]
    listDbView('mgr_message', 'General message log', search.strip())
  else: # letter corresponds to an error level
    if t.lower() in ['e', 'i', 'c', 'd', 'w']:
      listDbView('mgr_message', 'General message log', "level ilike '{}%'".format(t[:1]))
    else:
      print('Invalid message level specified')
    
def processCommand(cmd):
  task = cmd.strip()
  if task[:1].lower() == 'q':
    sys.exit(0)
#  try:
  if task[:1].lower() == 'h':
    showHelp()
  elif task[:1].lower() == 'w':
    workerTask(task)
  elif task[:1].lower() == 'p':
    instanceTask(task)
  elif task[:1].lower() == 'c':
    catalogTask(task)
  elif task[:1].lower() == 'm':
    messageTask(task)
  elif task[:1].lower() == 'd':
    dumpjobTask(task)
  elif task[:1].lower() == 'r':
    restorejobTask(task)
  elif task[:1].lower() == 'l':
    restorelogTask(task)
#  except Exception:
#    print Exception
#    print('Invalid command, options (like a non-existing id)')
      
# ================================================================
# 'MAIN'
# ================================================================

if len(sys.argv) > 1:
  if sys.argv[1][:1] == 'h':
    showHelp()
    sys.exit(0)

config = ConfigParser.RawConfigParser(allow_no_value=True)
config.read('defaults.cfg')
PGSCHOST=config.get('snapman_database', 'pgschost')
PGSCPORT=config.get('snapman_database', 'pgscport')
PGSCUSER=config.get('snapman_database', 'pgscuser')
PGSCDB=config.get('snapman_database', 'pgscdb')
PGSCPASSWORD=config.get('snapman_database', 'pgscpassword')

print(' +---------------------------------------+')
print(' | PgSnapMan manager (c) W. Boasson 2017 |')
print(' +---------------------------------------+')
print(' PgSnapMan catalog: {}@{}:{}/{}'.format(PGSCUSER, PGSCHOST, str(PGSCPORT), PGSCDB))
sys.stdout.write(' Verifying database connection... ')
if PGSCPASSWORD == '':
  PGSCPASSWORD=getpass.getpass('password: ')
try:
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  conn.close()
  print('ok')
except:
  print('\nCould not connect to database, check settings in default.cfg')
  sys.exit(1)
print ''

cmd = ''
if len(sys.argv) > 1:
  for a in range(1, len(sys.argv)):
    cmd = cmd + ' ' + str(sys.argv[a])
  processCommand(cmd)
  sys.exit(0)

showHeader()

while True:
  task=raw_input('Enter command (q=quit, h=help): ')
  processCommand(task)
