ALTER TABLE pgsnap_restorelog DROP CONSTRAINT fk_pgsnap_restorelog_pgsnap_restorejob ;

ALTER TABLE pgsnap_restorelog
  ADD CONSTRAINT fk_pgsnap_restorelog_pgsnap_restorejob FOREIGN KEY (pgsnap_restorejob_id)
      REFERENCES pgsnap_restorejob (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;
