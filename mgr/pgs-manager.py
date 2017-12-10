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
  elif value.strip() == '':
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
  print('Enter new values:')
  print('  (use exactly one space to clear a field):')
  print ''.ljust(48, '-')
  for c in editcols:
    if row[c] == None:
      dispval = ''
    else:
      dispval = row[c]
    newval = raw_input(('{} [{}]'.format(c, dispval)).ljust(26, ' ') + ': ')
    if newval == ' ':
      row[c] = ''
    elif newval.strip() != '':
      row[c] = newval.strip()
  print('')
  print('Edited values:')
  print ''.ljust(48, '-')
  for c in editcols:
    print('{}'.format(c).ljust(26, ' ') + str(row[c]))
  yn = raw_input('Save new values [yN]? ')
  if yn == 'y':
    for c in editcols:
      setTableColumn(tablename, c, id, row[c])
    listDetails(tablename, id, 'Verify update results')
  print('')
  
  #print(diffset())
#  cols = "select * from  where table_name = %s;"
#  sql = "select * from  where id = %s;".format(tablename, column)

def intersect(a, b):
    return list(set(a) & set(b))

def diffset(a, b):
    return list(set(a) - set(b))

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
  worker add
  worker status [ACTIVE|HALTED]
  worker edit <id>
  worker delete [dns_name]
  
postgres management
-------------------
  postgres list
  postgres list+<id>
  postgres add
  postgres status [ACTIVE|HALTED]
  postgres edit <id>
  postgres delete [dns_name:port]

catalog management
------------------
  catalog list
  catalog list+<id>
  catalog search <filter>
  catalog keep [NO|YES|AUTO]
  
    <filter>: regular Postgres filter, you may filter on every
              column available in the view; for security reasons
              using a ; is not allowed
             
  Example 1: list entire dump catalog
  c l

  Example 2: list details of dump id=123
  c l+123

  Example 3: search for all long running dumps (> 10 minutes)
  c s duration > '10 minutes'::interval

  Example 4: search for all dumps manually marked as keep=YES
  c s keep='YES'

dump job management
-------------------
  dumpjob list
  dumpjob list+<id>
  dumbjob edit <id>
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
  elif t == 'k': # set keep status
    tokens = task.split(' ')
    id = tokens[2]
    col = tokens[3]
    val = tokens[4]
    setTableColumn('pgsnap_catalog', col, id, val, True)

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
    restoreTask(task)
#  except Exception:
#    print Exception
#    print('Invalid command, options (like a non-existing id)')
      
# ================================================================
# 'MAIN'
# ================================================================

showHeader()

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

print('PgSnapMan catalog: {}@{}:{}/{}'.format(PGSCUSER, PGSCHOST, str(PGSCPORT), PGSCDB))
print('')
sys.stdout.write('Verifying database connection... ')
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

while True:
  task=raw_input('Enter command (q=quit, h=help): ')
  processCommand(task)
