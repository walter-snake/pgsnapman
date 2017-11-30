# Extracts create database statements from a postgres custom/directory dump
# Tablespaces are stripped of by default, when setting the variable INCLUDETS to Y
# tablespaces are included.
#
# Example calls:
#   cat yourschema.sql | awk -v INCLUDETS="Y" extractcreatedb.awk or straight from a dump
#   pg_restore --create --schema-only yourdump | awk -v INCLUDETS="Y" extractcreatedb.awk

{ T=0
  P=0
  if ($1=="CREATE" && $2=="DATABASE") {
    if ( INCLUDETS == "Y" )
      print $0
    else {
      for (i=1; i <= NF; i++) {
        if ($i == "TABLESPACE")
          T=i
        if (T==0 || i<T || i>=T+3) {
          P=i
          printf($i" ")
        }
      }
      # If something was stripped of, add ;
      if ($P ~ /;/)
        print ""
      else
        print ";"
    }
  }
  if ($1=="ALTER" && $2=="DATABASE")
    print $0
}
