-- Function: get_keep_catjobid(timestamp with time zone, integer, integer, integer, integer, integer)

-- DROP FUNCTION get_keep_catjobid(timestamp with time zone, integer, integer, integer, integer, integer);

CREATE OR REPLACE FUNCTION get_keep_catjobid(datenow timestamp with time zone, jobid integer, days integer, weeks integer, months integer, years integer)
  RETURNS SETOF record AS
$BODY$
declare
  keep_slicestart timestamp with time zone;
  keep_sliceend timestamp with time zone;
  dj record;
  r record;
  keep_id record;
  keep_ids integer[];
begin

  -- initialize, end of first slice
  keep_sliceend := $1::date + ('1 day')::interval;
  keep_ids := ARRAY[]::integer[];

  -- 1 per day
  --raise notice 'Daily clean up, end date at start: %', keep_sliceend;
  for i in 1..days loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' days')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
      order by starttime desc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'D % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;
    
  -- 1 per week
  --raise notice 'Weekly clean up, end date at start: %', keep_sliceend;
  for i in 1..weeks loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' weeks')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
      order by starttime asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'W % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;
  
  -- 1 per month
  --raise notice 'Monthly clean up, end date at start: %', keep_sliceend;
  for i in 1..months loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' months')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
     order by starttime asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'M % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;


  -- 1 per year
  --raise notice 'Yearly clean up, end date at start: %', keep_sliceend;
  for i in 1..years loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' year')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend) overlaps (starttime, starttime)
        and status = 'SUCCESS'
        and pgsnap_dumpjob_id = jobid
        and keep = 'AUTO'
       order by starttime asc limit 1
    loop
      if NOT r.id IS NULL then
        keep_ids := array_append(keep_ids, r.id);
      end if;
      raise notice 'Y % % [%..%]', i, r.id, keep_slicestart, keep_sliceend;    
    end loop;
    -- set new slice end date
    keep_sliceend := keep_slicestart;
  end loop;

  -- all catalog entries marked as keep, or linked to a restore job
  for r in select id
    from pgsnap_catalog
    where keep = 'YES'
    or id in (select pgsnap_catalog_id from pgsnap_restorejob)
  loop
      if NOT keep_ids @> ARRAY[r.id] then
        keep_ids := array_append(keep_ids, r.id);
        raise notice 'U - %', r.id;
	      end if;
  end loop;
     
  -- output
  --raise notice 'Keeping: %', array_length(keep_ids, 1);
  for keep_id in select unnest(keep_ids)
  loop
    return next keep_id;
  end loop;
  return;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
