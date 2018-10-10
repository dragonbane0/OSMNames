DELETE FROM osm_point a
      USING osm_point b
WHERE a.ctid < b.ctid
      AND a.name = b.name 
	  AND a.parent_id = b.parent_id 
	  AND a.class = b.class
	  AND st_dwithin(a.geometry, b.geometry, 1000) 
	  AND a.parent_id IS NOT NULL 
	  AND a.id != b.id;