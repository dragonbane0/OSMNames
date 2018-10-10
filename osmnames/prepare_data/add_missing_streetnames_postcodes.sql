DROP FUNCTION IF EXISTS nearest_street(BIGINT, geometry, TEXT, TEXT);
CREATE FUNCTION nearest_street(parent_id_in BIGINT, geometry_in GEOMETRY, currentStreet TEXT, currentPost TEXT)
RETURNS TABLE(streetName TEXT, postCode TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT COALESCE(currentStreet, street.streetName), COALESCE(currentPost, street.postCode)
    FROM osm_linestring AS street
    WHERE parent_id = parent_id_in
          AND st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

UPDATE osm_linestring
  SET (streetName, postCode) = (SELECT * FROM nearest_street(parent_id, geometry, streetName, postCode))
WHERE (streetName IS NULL OR postCode IS NULL)
      AND parent_id IS NOT NULL;

UPDATE osm_polygon
  SET (streetName, postCode) = (SELECT * FROM nearest_street(parent_id, geometry, streetName, postCode))
WHERE (streetName IS NULL OR postCode IS NULL)
      AND parent_id IS NOT NULL;

UPDATE osm_point
  SET (streetName, postCode) = (SELECT * FROM nearest_street(parent_id, geometry, streetName, postCode))
WHERE (streetName IS NULL OR postCode IS NULL)
      AND parent_id IS NOT NULL;
