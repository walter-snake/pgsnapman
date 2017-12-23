#! /usr/bin/env python

# PgSnapMan manager: list, upload, delete postgres instances, workers, jobs catalog entries

import readline
import sys
import os
import signal
from os.path import expanduser
from configreader import ConfigReader
import getpass
import psycopg2
from psycopg2 import extras
import prettytable
from prettytable import PrettyTable
from prettytable import from_db_cursor
from texttable import Texttable

# display mode
DISPMODE = 'li'

# dicts with abbreviations
# overviews, details, titles
views = { 'wo' : 'mgr_worker', 'po' : 'mgr_instance', 'du' : 'mgr_dumpjob'
  , 'ca' : 'mgr_catalog', 're' : 'mgr_restorejob', 'lo' : 'mgr_restorelog'
  , 'me' : 'mgr_message', 'ac' : 'pgsnap_activity', 'db' : 'mgr_database'
  , 'co': 'mgr_copyjob'}
tables = { 'wo' : 'pgsnap_worker', 'po' : 'pgsql_instance', 'du' : 'pgsnap_dumpjob'
  , 'ca' : 'pgsnap_catalog', 're' : 'pgsnap_restorejob', 'lo' : 'pgsnap_restorelog'
  , 'me' : 'pgsnap_message', 'ac' : 'pgsnap_activity' 
  , 'co' : 'mgr_copyjob_detail'}
titles = { 'wo' : 'PgSnapMan worker', 'po' : 'Postgres instance', 'du' : 'Dump job'
  , 'ca' : 'Backup catalog', 're' : 'Restore job', 'lo' : 'Restore log'
  , 'me' : 'System message', 'ac' : 'Activity/running processes', 'db' : 'Database overview'
  , 'co' : 'Copy jobs (linked dump and restore jobs)'}
# Filters
hourfilters = { 'ca' : 'starttime', 'lo' : 'starttime' , 'me' : 'logtime', 'ac' : 'starttime'
  , 'du' : 'date_added', 're' : 'date_added' , 'wo' : 'date_added', 'po' : 'date_added'
  , 'db' : 'date_added', 'co' : 'date_added'}
dbfilters = { 'ca': "split_part(id_db_schema, '/', 2) like '{}.%'"
  , 'lo': "split_part(id_db_schema, '/', 2) like '{}.%'"
  , 're': "'{}' in (split_part(s_db_schema, '.', 1), d_dbname)"
  , 'du': "dbname like '{}'" 
  , 'db': "dbname like '{}'" 
  , 'co': "'{}' in (split_part(s_db_schema, '.', 1), split_part(d_db_schema, '.', 1))"}
jobidfilters = { 'du' : 'id={}'
  , 're' : 'id={}'
  , 'ca' : "split_part(id_db_schema, '/', 1) like '{}'"
  , 'lo' : "split_part(id_db_schema, '/', 1) like '{}'"
  , 'co' : "did = {}"  }
schedulefilters = { 'du' : "substr(schedule, 1, 1) = substr(upper('{}'), 1, 1)"
  , 're' : "substr(schedule, 1, 1) = substr(upper('{}'), 1, 1)" 
  , 'co' : "substr(schedule, 1, 1) = substr(upper('{}'), 1, 1)" }
statusfilters = { 'po' : "substr(status, 1, 1) = substr(upper('{}'), 1, 1)"
  , 'wo' : "substr(status, 1, 1) = substr(upper('{}'), 1, 1)"
  , 'du' : "substr(status, 1, 1) = substr(upper('{}'), 1, 1)"
  , 're' : "substr(status, 1, 1) = substr(upper('{}'), 1, 1)" 
  , 'co' : "substr(dstatus, 1, 1) = substr(upper('{}'), 1, 1)" }
  
def get_script_path():
    return os.path.dirname(os.path.realpath(sys.argv[0]))

def exportDbView(viewname):
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  cur.execute('SELECT * FROM ' + viewname + ';')
  rows = cur.fetchall()
  pr = []
  colnames = [desc[0] for desc in cur.description]
  for c in colnames:
    pr.append(str(c))
  print("\t".join(pr))
  pr = []
  for r in rows:
    for e in r:
      pr.append(str(e))
    print("\t".join(pr))
    pr = []
  
def listDbView(viewname, title, search, idsort, limit = ''):
  if search.find(';') >= 0:
    print('WARNING: invalid filter, has been reset')
    search='true'
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  if not limit == '':
    limit = 'limit {}'.format(limit)
  if idsort == 'asc':
    sort = 'order by id asc'
  elif idsort == 'desc':
    sort = 'order by id desc'
  else:
    sort = ''
  try:
    cur.execute('SELECT * FROM {} WHERE {} {} {};'.format(viewname, search, sort, limit))
  except psycopg2.ProgrammingError, e:
    cur.close()
    conn.close()
    print(e.message)
    return

  print('')
  print(title)
  if not search == 'true':
    print('Filter: ' + search)
    print('')

  t = from_db_cursor(cur)
  conn.commit()
  conn.close()
  t.align = 'l'
  
  print(t)
    
  print(title)
  print('')
  if not search == 'true':
    print('Filter: ' + search)
    print('')

def listDetails(tablename, id, title):
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
  cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
  cur.execute('SELECT * FROM ' + tablename + ' WHERE id = %s;', (id, ))  
  rows = cur.fetchall()  
  cur.close()
  conn.close()
  if len(rows) == 0:
    print("ERROR id {} not found\n".format(str(id)))
    return False
  
  for r in rows:
    colnames = [desc[0] for desc in cur.description]
    print ''
    print title
    print ''.ljust(48, '-')
    for c in colnames:
      print(c.ljust(26) + str(r[c]))
    print ''
  return True

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
  if not listDetails(tablename, id, 'Current record: {} [{}]'.format(tablename, id)):
    return
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

def insertInstance(dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment, def_jobstatus):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'insert into pgsql_instance (dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment, def_jobstatus) VALUES (%s, %s, %s, %s, %s, %s, %s, %s) returning id;'
    cur.execute(sql, (dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment, def_jobstatus))
    row = cur.fetchone()
    print('-> Registered postgres instance with id: {}'.format(row[0]))
    conn.commit()
    conn.close()
    return row[0]
    
def insertDumpJob(pgsnap_worker_id, pgsql_instance_id, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, status, pgsnap_restorejob_id):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'insert into pgsnap_dumpjob (pgsnap_worker_id, pgsql_instance_id, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, status, pgsnap_restorejob_id) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) returning id;'
    cur.execute(sql, (pgsnap_worker_id, pgsql_instance_id, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, status, pgsnap_restorejob_id))
    row = cur.fetchone()
    print('-> Created dump job with id: {}'.format(row[0]))
    conn.commit()
    conn.close()
    return row[0]
    
def insertRestoreJob(dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = 'insert into pgsnap_restorejob (dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) returning id;'
    if pgsnap_catalog_id == -1:
      pgsnap_catalog_id = None
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

def removeAllBackupsForDumpJob(id):
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = "select count(*) from pgsnap_catalog where pgsnap_dumpjob_id = %s"
    cur.execute(sql, (id, ))
    c = cur.fetchone()[0]
    conn.close()
    yn = raw_input('Do you really want to delete all ({}) backups for job id {}? [yN] '.format(str(c), str(id)))
    if not yn.lower() == 'y':
      return
    print('Marking backups to be removed...')
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
    cur = conn.cursor()
    sql = "update pgsnap_catalog set keep = 'NO' where pgsnap_dumpjob_id = %s"
    cur.execute(sql, (id, ))
    conn.commit()
    conn.close()
    print('-> Marked {} catalog entries for removal'.format(str(c)))
  
def getInstanceDumps(dns_name, port):
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))  
  cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
  sql = """with dbr as (select dbname, max(starttime) as st from pgsnap_catalog c where pgsql_dns_name = %s and pgsql_port = %s and status = 'SUCCESS' and keep in ('AUTO', 'YES') and dumptype = 'FULL' and dumpschema = '*' group by dbname) select id as cat_id, bu_worker_id as worker_id, c.dbname, st from pgsnap_catalog c join dbr on dbr.st = c.starttime and dbr.dbname = c.dbname where pgsql_dns_name = %s and pgsql_port= %s and dbr.dbname not like '{}';""".format(MAINTDB)
  cur.execute(sql, (dns_name, port, dns_name, port))
  rows = cur.fetchall()
  conn.close()  
  return rows
  
def getInput(message, values, defval, width = 32, allowempty = True):
  ri = ''
  # need strings for comparison
  chkvals = []
  for e in values: chkvals.append(str(e))
  while ri not in values or len(values) == 1 or ri in ['?', '']:
    ri = raw_input('{} [{}]'.format(message, defval).ljust(width, ' ') + ': ')
    if ri == '?':
      print '  ' + str(values[0])
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
      if ri in chkvals or len(values) == 1:
        return ri

# register worker
def registerWorker():
  print('')
  print('Register a pgsnapman worker, enter values (list of options/help tekst: ?):')
  dns_name = getInput('worker dns name:', ['dns name as reported by hostname -f or name set in worker config'], '', 54, False)
  cron_cacheconfig = getInput('cache refresh cron:', ['numeric cron entry'], '0 * * * *', 54, False)
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
  bu_window_start = getInput('backup window start hour:', ["hour: the start of the time range that will be used to automatically generate a \n  backup time, you may always set the backup to any desired schedule\n    (0-23)"], '20', 54, False)
  bu_window_end = getInput('backup window end hour:', ["hour: the end of the time range that will be used to automatically generate a \n  backup time, you may always set the backup to any desired schedule\n    (0-23)"], '6', 54, False)
  pgsnap_worker_id_default = getInput('default pgsnapman worker', ['id of an existing worker'], '', 54, False)
  def_jobstatus = getInput('auto-add job status', ['default status for auto-added jobs', 'INHERIT', 'ACTIVE', 'HALTED'], 'INHERIT', 54, False)
  comment = getInput('comment', ['optional comments'], '', 54)
  yn = raw_input('Save new instance? [Yn] ')
  if not yn.lower() == 'n':
    id = insertInstance(dns_name, pgport, pgsql_superuser, bu_window_start, bu_window_end, pgsnap_worker_id_default, comment, def_jobstatus)
    listDetails('pgsql_instance', id, 'Verify instance details')
    print('')
    yn = raw_input('Do you want to edit the instance? [yN] ')
    if yn.lower() == 'y':
      editRecord('pgsql_instance', id, ['status', 'pgsql_superuser', 'bu_window_start', 'bu_window_end', 'pgsnap_worker_id_default', 'def_jobstatus', 'comment'])
  print('')

# add dump job
def addDumpJob(_status = 'ACTIVE'):
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
  trigger = getInput('trigger', ['restore jobs to start, comma separated id list without spaces'], '', 54)
  comment = getInput('comment', ['optional comments'], '', 54)
  yn = raw_input('Save new job? [Yn] ')
  if yn.lower() == 'n':
    print('')
    return None
  else:
    id = insertDumpJob(workerid, pgsqlid, dbname, dumptype, dumpschema, dumpoptions, comment, cron, jobtype, _status, trigger)
    listDetails('pgsnap_dumpjob', id, 'Verify job details')
    print('')
    yn = raw_input('Do you want to edit the job? [yN] ')
    if yn.lower() == 'y':
      editRecord('pgsnap_dumpjob', id, ['jobtype', 'cron', 'dumpoptions', 'keep_daily', 'keep_weekly', 'keep_monthly', 'keep_yearly',  'pgsnap_restorejob_id', 'comment', 'status'])    
    print('')
    print('Status of job: ' + _status)
    return id

# delete dump job
def deleteDumbJob(id):
  print """
Delete a dump job

Keep the following in mind:
* If the database still exists and AUTO_DUMPJOB=YES, a new job will be created (which is NOT linked to existing backups).
* Already made backups will remain in the catalog and will be removed according to the deleted jobs retention policy, unless you mark the backups to be removed too.'
"""
  yn = raw_input('Mark backups for dump job {} for removal? [yN] '.format(str(id)))
  if yn == 'y':
    removeAllBackupsForDumpJob(id)  
  deleteFromDb('pgsnap_dumpjob', id)

# add restore job
def addRestoreJob(_trigger = False):
  print('')
  print('Add a restore job, enter values (list of options/help tekst: ?):')
  if _trigger == True:
    jobtype = 'TRIGGER'
    pgsnap_catalog_id = -1
  else:
    jobtype = getInput('job type', ['choose one from', 'SINGLE', 'REPEAT', 'TRIGGER'], 'SINGLE', 54, False)
    if jobtype == 'TRIGGER':
      pgsnap_catalog_id = -1
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
  if yn.lower() == 'n':
    print('')
    return None
  else:
    id = insertRestoreJob(dest_pgsql_instance_id, dest_dbname, restoretype, restoreschema,restoreoptions, existing_db, comment, jobtype, cron, pgsnap_catalog_id, role_handling, tblspc_handling)
    listDetails('pgsnap_restorejob', id, 'Verify job details')
    print('')
    yn = raw_input('Do you want to edit the job? [yN] ')
    if yn.lower() == 'y':
      editRecord('pgsnap_restorejob', id, ['jobtype', 'cron', 'dest_pgsql_instance_id', 'dest_dbname', 'restoretype', 'restoreschema', 'restoreoptions', 'role_handling', 'tblspc_handling', 'comment', 'status'])
    print('')
    return id

def clearActivity():
  yn = raw_input('Do you want to clear the activity table (it does not affect running processes)? [yN] ')
  if yn.lower() == 'y':
    sql = 'delete from pgsnap_activity'
    conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
    cur = conn.cursor()
    cur.execute(sql)
    conn.commit()
    conn.close()
  
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
  print('PgSnapMan catalog: {}@{}:{}/{}'.format(PGSCUSER, PGSCHOST, str(PGSCPORT), PGSCDB))
  print('')

def showHelp():
  print """
Available commands
==================

General
-------
q: quit
h: this help

* The commands may be abbreviated to the first two letters.
* Choice:       [choice1|choice2|...]
* Optional:     ()
* Variable:     <id>
* Full details: list+<id>

It is also possible to enter the commands directly on the command line
when calling pgs-manager.

Worker management
-----------------
  worker list(.options) (filter)
  worker register
  worker status [ACTIVE|HALTED]
  worker edit <id>
  worker delete <id>
  worker export
  
Postgres management
-------------------
  postgres list(.options) (filter)
  postgres register
  postgres status [ACTIVE|HALTED]
  postgres edit <id>
  postgres delete <id>
  postgres export

Dump job management
-------------------
  dumpjob list(.options) (filter)
  dumpjob add
  dumpjob status [ACTIVE|HALTED]
  dumbjob edit <id>
  dumbjob clear-dumps <id>
  dumbjob delete <id>
  dumpjob export

Restore job management
----------------------
  restorejob list(.options) (filter)
  restorejob add
  restorejob status [ACTIVE|HALTED]
  restorejob edit <id>
  restorejob delete <id>
  restorejob export
  
  serverrestore <src_dns_name> <src_port> <dest_dns_name> <dest_port>

Copy jobs
------------
  copyjob list(.options) (filter)
  copyjob add

Catalog management
------------------
  catalog list(.options) (filter)
  catalog keep [NO|YES|AUTO]
  catalog export

Log of restore jobs
-------------------
  log-restore(.options) (filter)
  log-restore export
  
Miscellaneous lists
-------------------
  message list(.options) (filter)
  message export
  
  activity list(.options) (filter)
  
  database list(.options) (filter)
  
Option and filter syntax
------------------------
.options: list sorting, limiting
           .asc
           .desc
           .<limit>
filter:  filter options, either one of the predefined filters
           id=<id> full details
           .hour=<hours_back_from_now> (on every list with a time stamp,
                                        fractional hours allowed)
           .jobid=<job_id> (on dump job and catalog, and on restore job
                            and restore log lists)
           .schedule=[REPEAT|SINGLE|TRIGGER] (on dump, restore and copy job)
           .status=[ACTIVE|HALTED] (on worker, pgsql instance, dump job,
                             restore job and copy job)
           .db=<database_name> (on database, dump, restore, copy, catalog and
                                restore log lists, wildchard % allowed)
           "<postgres_filter" regular Postgres filter, you may filter on every
                              column available in the view; for security
                              reasons using a ; is not allowed

         Note: for jobtype and status only the first letter is needed.
                              
"""  

# Generic list viewer
def listView(task):
  tokens = task.split(' ')
  list = task.split(' ')[0][:2]

  # filter out the sort options (list.asc or list.desc)
  subtokens = tokens[1].split('.')
  sort = ''
  limit = ''
  for tok in range(1, len(subtokens)):
    if subtokens[tok] in ['asc','desc']:
      sort = subtokens[tok]
    else:
      limit = subtokens[tok]

  # figure out if we have to print details, or that the 3rd and following tokens are a more complex filter
  # an id only: automatically print details
  if len(tokens) >= 3:
    if tokens[2].startswith('id=') and len(tokens) == 3:
    # special case: id only -> details
      id = str(tokens[2].split('=')[1].strip())
      listDetails(tables[list], id, titles[list])
    else:
    # filter
      search=''
      for tok in range(2, len(tokens)):
        search = search + ' ' + tokens[tok]
        search = processFilter(list, search.strip())
      listDbView(views[list], titles[list], search, sort, limit)
  else:
    try:
      listDbView(views[list], titles[list], 'true', sort, limit)
    except KeyError, e:
      print('ERROR Unknown list specified: {}'.format(list))

# process filter (detect special filters, starting with .keyword= (dot-keyword-equals)
def processFilter(list, filter):
  # quick return
  if not filter.startswith('.'):
    return filter
  try:
    val = str(filter.split('=')[1].strip())
    if filter.startswith('.hour='):
      return "(now() - {}::timestamp without time zone) < '{} hours'::interval".format(hourfilters[list], val)
    elif filter.startswith('.jobid='):
      return jobidfilters[list].format(val)
    elif filter.startswith('.schedule='):
      return schedulefilters[list].format(val)
    elif filter.startswith('.db='):
      return dbfilters[list].format(val)
    elif filter.startswith('.status='):
      return statusfilters[list].format(val)
    else:
      print('ERROR Unkown filter specified.')
      return 'false'
  except KeyError, e:
    print('ERROR Filter not defined for this list.')
    return 'false'

# Generic list viewer
def exportView(task):
  tokens = task.split(' ')
  list = task.split(' ')[0][:2]
  exportDbView(views[list])

def workerTask(task):
  t = task.split(' ')[1][:2]
  tokens = task.split(' ')
  if t == 'st': # set status
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsnap_worker', 'status', id, status, True)
  elif t == 'ed': # edit record
    id = tokens[2]
    editRecord('pgsnap_worker', id, ['cron_cacheconfig', 'cron_singlejob', 'cron_clean', 'cron_upload', 'status', 'comment'])
  elif t == 're': # register worker   
    registerWorker()
  elif t == 'de': # delete worker
    id = tokens[2]
    deleteFromDb('pgsnap_worker', id)
  else:
    print("ERROR unknown sub command\n")

def instanceTask(task):
  t = task.split(' ')[1][:2]
  tokens = task.split(' ')
  if t == 'st': # set status
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsql_instance', 'status', id, status, True)
  elif t == 'ed': # edit record
    id = tokens[2]
    editRecord('pgsql_instance', id, ['pgsql_superuser', 'bu_window_start', 'bu_window_end', 'pgsnap_worker_id_default', 'def_jobstatus', 'status', 'comment'])
  elif t == 're': # register instance
    registerInstance()
  elif t == 'de': # delete instance
    id = tokens[2]
    deleteFromDb('pgsql_instance', id)
  else:
    print("ERROR unknown sub command\n")

def dumpjobTask(task):
  t = task.split(' ')[1][:2]
  tokens = task.split(' ')
  if t == 'st': # set status
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsnap_dumpjob', 'status', id, status, True)
  elif t == 'ed': # edit record
    id = tokens[2]
    editRecord('pgsnap_dumpjob', id, ['jobtype', 'cron', 'dumpoptions', 'keep_daily', 'keep_weekly', 'keep_monthly', 'keep_yearly', 'pgsnap_restorejob_id', 'status', 'comment'])
  elif t == 'ad': # add dumpjob    
    addDumpJob()
  elif t == 'de': # delete dumpjob
    id = tokens[2]
    deleteDumbJob(id)
  elif t == 'cl': # clear dumps
    id = tokens[2]
    removeAllBackupsForDumpJob(id)
  else:
    print("ERROR unknown sub command\n")

def restorejobTask(task):
  t = task.split(' ')[1][:2]
  tokens = task.split(' ')
  if t == 'st': # set status
    id = tokens[2]
    status = tokens[3]
    setTableColumn('pgsnap_restorejob', 'status', id, status, True)
  elif t == 'ed': # edit record
    id = tokens[2]
    editRecord('pgsnap_restorejob', id, ['jobtype', 'cron', 'dest_pgsql_instance_id', 'dest_dbname', 'restoretype', 'restoreschema', 'restoreoptions', 'role_handling', 'tblspc_handling', 'status', 'comment'])
  elif t == 'ad': # add restorejob    
    addRestoreJob()
  elif t == 'de': # delete restorejob
    id = tokens[2]
    deleteFromDb('pgsnap_restorejob', id)
  else:
    print("ERROR unknown sub command\n")
  
def catalogTask(task):
  tokens = task.split(' ')
  t = task.split(' ')[1][:2]
  if t == 'ke': # set keep status
    id = tokens[2]
    val = tokens[3]
    setTableColumn('pgsnap_catalog', 'keep', id, val, True)
  else:
    print("ERROR unknown sub command\n")

def copyTask(task):
  tokens = task.split(' ')
  t = task.split(' ')[1][:2]
  if not t == 'ad':
    print("ERROR unknown sub command\n")
    return

  # create one or more restorejob tasks, and call dumpjob with new ids
  print("Create a 'copy' job")
  print("===================")
  print("Step 1: create the dump job, when done one or more restore jobs can be created. They're automatically linked together, so that after running the dump job, the restore jobs will run based on that specific run of the dump. The dump job will put on halt, until the procedure is complete.")
  print('')
  djid = addDumpJob('HALTED')
  rjids = []
  if djid  == '' or djid == None:
    return
  else:
    print('')
    print('Step 2: create one or more restore jobs')
    a = 'y'
    while a == 'y':
      id = addRestoreJob(True)
      if not id == '' or id == None:
        rjids.append(str(id))
      a = raw_input('Add another restore job? [yN]')
    s = ','
    restore_jobs = s.join(rjids)
    setTableColumn('pgsnap_dumpjob', 'pgsnap_restorejob_id', djid, restore_jobs, False)
    setTableColumn('pgsnap_dumpjob', 'status', djid, 'ACTIVE', True)

def activityTask(task):
  tokens = task.split(' ')
  t = task.split(' ')[1][:2]
  if t == 'cl': # clear
    clearActivity()
  else:
    print("ERROR unknown sub command\n")

def serverrestoreTask(task):
  tokens = task.split(' ')
  dns_name = tokens[1]
  port = tokens[2]
  dest_dns_name = tokens[3]
  dest_port = tokens[4]
  print('Create a server restore task: automatically generate restore jobs for')
  print('all available FULL dumps without schema restrictions.')
  print('')
  print('Collecting all available dumps for: {}:{}').format(dns_name, port)
  dumps = getInstanceDumps(dns_name, port)  
  t = PrettyTable(['cat_id', 'worker_id','dbname', 'dump_timestamp'])
  for d in dumps:
    t.add_row([d['cat_id'], d['worker_id'], d['dbname'], d['st']])
  t.align = 'l'
  print(t)
  print('')
  print('Looking up pgsql instance id for: {}:{}').format(dest_dns_name, dest_port)
  dest_pgsql_instance_id = getPgsqlInstanceId(dest_dns_name, dest_port)
  if  dest_pgsql_instance_id == None:
    print('ERROR Destination pgsql instance id not found.')
    return
  else:
    print('-> destination pgsql instance id: {}').format(str(dest_pgsql_instance_id))
    print('Generating restore jobs for restoring into pgsql instance: {}:{}').format(dest_dns_name, dest_port)
    print('Skipping maintenance database: {}'.format(MAINTDB))
    c = 0
    cron='* * * * *'
    for d in dumps:
      insertRestoreJob(dest_pgsql_instance_id, d['dbname'], 'FULL', '*', '', 'DROP', 'generated server restore job', 'SINGLE', cron, d['cat_id'], 'USE_ROLE', 'USE_TBLSPC')
      c += 1
    print('Created {} jobs, starting as soon as possible'.format(str(c)))

def processCommand(cmd):
  try:
    task = cmd.strip()
    # multiple token commands first
    if len(task.split()) >= 2:
      if task.split()[1][:2].lower() == 'li':
        listView(task)
      elif task.split()[1][:2].lower() == 'ex':
        exportView(task)    
      elif task[:2].lower() == 'wo':
        workerTask(task)
      elif task[:2].lower() == 'po':
        instanceTask(task)
      elif task[:2].lower() == 'du':
        dumpjobTask(task)
      elif task[:2].lower() == 'ca':
        catalogTask(task)
      elif task[:2].lower() == 're':
        restorejobTask(task)  
      elif task[:2].lower() == 'ac':
        activityTask(task)  
      elif task[:2].lower() == 'co':
        copyTask(task)
      elif task[:2].lower() == 'se':
        serverrestoreTask(task)
      else:
        print("ERROR unknown command\n")
    else: 
      if task[:].lower() == 'q':
        sys.exit(0)
      elif task[:1].lower() == 'h':
        showHelp()
      elif len(task.split()) == 1 :
        listView(task + ' li .hour=24')
      else:
        print("ERROR unknown command\n")
  except Exception:
    print Exception
    print('ERROR Invalid command or options (like a non-existing list or invalid options)')
      
# ================================================================
# 'MAIN'
# ================================================================

if len(sys.argv) > 1:
  if sys.argv[1][:1] == 'h':
    showHelp()
    sys.exit(0)

configfile = '/etc/pgsnapman/pgsnapman.config'  
if not os.path.exists(configfile):
  configfile = home = expanduser("~") + '/.pgsnapman.config'
if not os.path.exists(configfile):
  configfile =  get_script_path() + '/../bin/pgsnapman.config'
config = ConfigReader(configfile)
PGSCHOST=config.getval('PGSCHOST')
PGSCPORT=config.getval('PGSCPORT')
PGSCUSER=config.getval('PGSCUSER')
PGSCDB=config.getval('PGSCDB')
PGSCPASSWORD=config.getval('PGSCPASSWORD')
MAINTDB=config.getval('MAINTDB')

if MAINTDB == '':
  print('No maintenance db configured, exit.')
  sys.exit(1)

if PGSCPASSWORD == '':
  PGSCPASSWORD=getpass.getpass('password: ')
try:
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  conn.close()
except:
  print('\nCould not connect to database, check settings in pgsnapman.config')
  sys.exit(1)

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
