-- drop function get_keep_catjobid(timestamp without time zone, integer, integer, integer, integer, integer);

create or replace function get_keep_catjobid(datenow timestamp without time zone, jobid integer, days integer, weeks integer, months integer, years integer) returns setof record
as
$$
declare
  keep_slicestart timestamp without time zone;
  keep_sliceend timestamp without time zone;
  dj record;
  r record;
  keep_id record;
  keep_ids integer[];
begin

  -- initialize, end of first slice
  keep_sliceend := $1::date + ('1 day')::interval;

  -- 1 per day
  --raise notice 'Daily clean up, end date at start: %', keep_sliceend;
  for i in 1..days loop
    -- using overlaps, we're going to collect all ids in day intervals for i-days, and then pick the most recent
    keep_slicestart := keep_sliceend - (1 || ' days')::interval;
    for r in select id
      from pgsnap_catalog
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
      and pgsnap_dumpjob_id = jobid
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
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
      and pgsnap_dumpjob_id = jobid
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
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
       and pgsnap_dumpjob_id = jobid
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
      where (keep_slicestart, keep_sliceend)
        overlaps (starttime, starttime)
      and pgsnap_dumpjob_id = jobid
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

  -- output
  --raise notice 'Keeping: %', array_length(keep_ids, 1);
  for keep_id in select unnest(keep_ids)
  loop
    return next keep_id;
  end loop;
  return;
end;
$$
language 'plpgsql';

-- Test query
-- select * from get_keep_catjobid('20171128T080000', 3, 14, 2, 5, 2) as (id integer);
