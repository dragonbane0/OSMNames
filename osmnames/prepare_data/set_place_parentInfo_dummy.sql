DROP FUNCTION IF EXISTS get_parent_info(BIGINT, TEXT, TEXT, INTEGER, VARCHAR);
CREATE FUNCTION get_parent_info(id BIGINT, name TEXT, type TEXT, rank INTEGER, wikipedia VARCHAR)
RETURNS TABLE(county TEXT) AS $$
DECLARE
  current_name TEXT;
  current_rank INTEGER;
  current_id BIGINT;
  current_type TEXT;
  current_country_code VARCHAR(2);
  city_rank INTEGER := 16;
  county_rank INTEGER := 10;
BEGIN
  current_id := id;

  WHILE current_id IS NOT NULL LOOP
    SELECT p.name, p.place_rank, p.parent_id, p.type, p.country_code
    FROM osm_polygon AS p
    WHERE p.id = current_id
    INTO current_name, current_rank, current_id, current_type, current_country_code;

    CONTINUE WHEN current_type IN ('water', 'bay', 'desert', 'reservoir', 'pedestrian');
    EXIT WHEN current_rank = 4;

    IF current_rank BETWEEN 16 AND 22 THEN
      city_rank := current_rank;
    ELSIF (current_rank BETWEEN 10 AND city_rank) THEN
      county := current_name;
      county_rank := current_rank;
    ELSIF (current_rank BETWEEN 6 AND county_rank) THEN
    END IF;
  END LOOP;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


UPDATE osm_linestring SET (county) = (SELECT * FROM get_parent_info(parent_id, name, type, place_rank, wikipedia));
UPDATE osm_merged_linestring SET (county) = (SELECT * FROM get_parent_info(parent_id, name, type, place_rank, wikipedia));
UPDATE osm_polygon SET (county) = (SELECT * FROM get_parent_info(id, '', type, place_rank, wikipedia));
UPDATE osm_point SET (county) = (SELECT * FROM get_parent_info(parent_id, name, type, place_rank, wikipedia));

