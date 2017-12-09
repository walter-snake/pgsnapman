#! /bin/env/python

# PgSnapMan script manager: list, upload, delete a script file into the database

import psycopg2
import sys
import os
import ConfigParser
import getpass

config = ConfigParser.RawConfigParser(allow_no_value=True)
config.read('defaults.cfg')
PGSCHOST=config.get('snapman_database', 'pgschost')
PGSCPORT=config.get('snapman_database', 'pgscport')
PGSCUSER=config.get('snapman_database', 'pgscuser')
PGSCDB=config.get('snapman_database', 'pgscdb')
PGSCPASSWORD=config.get('snapman_database', 'pgscpassword')

print('')
print('+-----------------------------+')
print('|  pgsnapman script uploader  |')
print('+-----------------------------+')
print('')
print('Verifying database connection...')
if PGSCPASSWORD == '':
  PGSCPASSWORD=getpass.getpass('password: ')
try:
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  conn.close()
except:
  print('Could not connect to database, check settings in default.cfg')
  sys.exit(1)
  
def listScripts():
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  cur.execute('SELECT id, scriptname FROM pgsnap_script;')
  rows = cur.fetchall()
  print('')
  print('Available scripts:')
  print('| id   | scriptname' )
  print('+------|--------------------' )
  for row in rows:
    print('|' + str(row[0]).rjust(5,' ') + ' | ' + row[1])
  print('')
  conn.commit()
  conn.close()

def deleteScript():
  print('')
  scriptname=raw_input('Delete script (name): ') 
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  cur.execute("DELETE FROM pgsnap_script WHERE scriptname = %s;", (scriptname, ))
  conn.commit()
  conn.close()
  print('')
  
def uploadScript():
  print('')
  file=raw_input      ('Upload file: ')
  scriptname=raw_input('Script name: ') 
  f = open(file)
  scriptcode=f.read()
  f.close()
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  cur.execute("INSERT INTO pgsnap_script(scriptname, scriptcode) VALUES (%s, %s);", (scriptname, scriptcode))
  conn.commit()
  conn.close()
  print('')

while True:
 task=raw_input('List, Upload, Delete, Quit [LUDQ]: ')
 if task[:1].upper() == 'L':
   listScripts()
 elif task[:1].upper() == 'U':
   uploadScript()
 elif task[:1].upper() == 'D':
   deleteScript()
 elif task[:1].upper() == 'Q':
   sys.exit(0)

