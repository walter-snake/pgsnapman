#! /usr/bin/env python

# PgSnapMan script manager: list, upload, delete a script file into the database

import sys
import os
from os.path import expanduser
from configreader import ConfigReader
import getpass
import psycopg2
from prettytable import PrettyTable
from prettytable import from_db_cursor

def get_script_path():
    return os.path.dirname(os.path.realpath(sys.argv[0]))

configfile = '/etc/pgsnapman/pgsnapman.config'  
if not os.path.exists(configfile):
  configfile = home = expanduser("~") + '/.pgsnapman.config'
  print configfile
if not os.path.exists(configfile):
  configfile =  get_script_path() + '/../bin/pgsnapman.config'
config = ConfigReader(configfile)
PGSCHOST=config.getval('PGSCHOST')
PGSCPORT=config.getval('PGSCPORT')
PGSCUSER=config.getval('PGSCUSER')
PGSCDB=config.getval('PGSCDB')
PGSCPASSWORD=config.getval('PGSCPASSWORD')

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
  print('Could not connect to database, check settings in mgr-defaults.cfg')
  sys.exit(1)
print ''
  
def listScripts():
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  cur.execute('SELECT id, scriptname FROM pgsnap_script;')
  print('')
  print('Available scripts:')
  t = from_db_cursor(cur)
  print t
  conn.commit()
  conn.close()
  print('')

def deleteScript():
  print('')
  scriptname=raw_input('Delete script (name): ') 
  conn = psycopg2.connect('host={} port={} dbname={} user={} password={}'.format(PGSCHOST, PGSCPORT, PGSCDB, PGSCUSER, PGSCPASSWORD))
  cur = conn.cursor()
  cur.execute("DELETE FROM pgsnap_script WHERE scriptname = %s;", (scriptname, ))
  conn.commit()
  conn.close()
  print('')
  listScripts()
  
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
  listScripts()
  

while True:
 task=raw_input('List, Upload, Delete, Quit [l|u|d|q]: ')
 if task[:1].lower() == 'l':
   listScripts()
 elif task[:1].lower() == 'u':
   uploadScript()
 elif task[:1].lower() == 'd':
   deleteScript()
 elif task[:1].lower() == 'q':
   sys.exit(0)

