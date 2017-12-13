class ConfigReader:
  configfile = ''

  def __init__(self, configfile):
    self.configfile = configfile

  def getval(self, key):
    with open(self.configfile, 'r') as cf:
      for line in cf:
        if line.strip().split('=')[0] == key:
          return line.strip()[line.find('=') + 1:].strip('"').strip("'")

