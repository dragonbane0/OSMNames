DROP FUNCTION IF EXISTS contained_in_postal_boundary(geometry);
CREATE FUNCTION contained_in_postal_boundary(geometry_in GEOMETRY)
RETURNS TABLE(postCode TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT postal.postCode
    FROM osm_polygon AS postal
    WHERE type = 'postal_code'
          AND st_contains(geometry, geometry_in)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

--Poly functions
DROP FUNCTION IF EXISTS nearest_poly_get_post(geometry);
CREATE FUNCTION nearest_poly_get_post(geometry_in GEOMETRY)
RETURNS TABLE(postCode TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT poly.postCode
    FROM osm_polygon AS poly
    WHERE st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS nearest_poly_get_city(geometry);
CREATE FUNCTION nearest_poly_get_city(geometry_in GEOMETRY)
RETURNS TABLE(city TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT poly.city
    FROM osm_polygon AS poly
    WHERE st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


--Street Functions
DROP FUNCTION IF EXISTS nearest_street_get_name(BIGINT, geometry);
CREATE FUNCTION nearest_street_get_name(parent_id_in BIGINT, geometry_in GEOMETRY)
RETURNS TABLE(streetName TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT street.streetName
    FROM osm_linestring AS street
    WHERE parent_id = parent_id_in
          AND st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS nearest_street_get_post(geometry);
CREATE FUNCTION nearest_street_get_post(geometry_in GEOMETRY)
RETURNS TABLE(postCode TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT street.postCode
    FROM osm_linestring AS street
    WHERE st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS nearest_street_get_city(geometry);
CREATE FUNCTION nearest_street_get_city(geometry_in GEOMETRY)
RETURNS TABLE(city TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT street.city
    FROM osm_linestring AS street
    WHERE st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


--Point functions
DROP FUNCTION IF EXISTS nearest_point_get_post(geometry);
CREATE FUNCTION nearest_point_get_post(geometry_in GEOMETRY)
RETURNS TABLE(postCode TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT p.postCode
    FROM osm_point AS p
    WHERE st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS nearest_point_get_city(geometry);
CREATE FUNCTION nearest_point_get_city(geometry_in GEOMETRY)
RETURNS TABLE(city TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT p.city
    FROM osm_point AS p
    WHERE st_dwithin(geometry, geometry_in, 1000)
    ORDER BY st_distance(geometry, geometry_in) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


--Last attempt to fill in missing postal_codes by checking if the polygon/string/point is contained in a postal_code boundary regardless of parental hierarchy (for ranks > 18/town)
UPDATE osm_polygon
  SET (postCode) = (SELECT * FROM contained_in_postal_boundary(geometry))
WHERE postCode IS NULL
AND place_rank > 18;

UPDATE osm_linestring
  SET (postCode) = (SELECT * FROM contained_in_postal_boundary(geometry))
WHERE postCode IS NULL
AND place_rank > 18;

UPDATE osm_point
  SET (postCode) = (SELECT * FROM contained_in_postal_boundary(geometry))
WHERE postCode IS NULL
AND place_rank > 18;


--Fill in missing street names from close-by streets with same parent (only for ranks > 19/village)
UPDATE osm_polygon
  SET (streetName) = (SELECT * FROM nearest_street_get_name(parent_id, geometry))
WHERE streetName IS NULL
      AND parent_id IS NOT NULL
	  AND place_rank > 19;

UPDATE osm_linestring
  SET (streetName) = (SELECT * FROM nearest_street_get_name(parent_id, geometry))
WHERE streetName IS NULL
      AND parent_id IS NOT NULL
	  AND place_rank > 19;

UPDATE osm_point
  SET (streetName) = (SELECT * FROM nearest_street_get_name(parent_id, geometry))
WHERE streetName IS NULL
      AND parent_id IS NOT NULL
	  AND place_rank > 19;

--Fill in missing postal_codes from close-by polygons/streets/nodes regardless of parents (only for ranks > 22/neighbourhood)
--Polygons
UPDATE osm_polygon
  SET (postCode) = (SELECT * FROM nearest_poly_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

UPDATE osm_polygon
  SET (postCode) = (SELECT * FROM nearest_street_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

UPDATE osm_polygon
  SET (postCode) = (SELECT * FROM nearest_point_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

--Streets
UPDATE osm_linestring
  SET (postCode) = (SELECT * FROM nearest_poly_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

UPDATE osm_linestring
  SET (postCode) = (SELECT * FROM nearest_street_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

UPDATE osm_linestring
  SET (postCode) = (SELECT * FROM nearest_point_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

--Points
UPDATE osm_point
  SET (postCode) = (SELECT * FROM nearest_poly_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

UPDATE osm_point
  SET (postCode) = (SELECT * FROM nearest_street_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;

UPDATE osm_point
  SET (postCode) = (SELECT * FROM nearest_point_get_post(geometry))
WHERE postCode IS NULL
	  AND place_rank > 22;



--Fill in missing cities from close-by polygons/streets/nodes regardless of parents (only for ranks > 16/city)
--Polygons
UPDATE osm_polygon
  SET (city) = (SELECT * FROM nearest_poly_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

UPDATE osm_polygon
  SET (city) = (SELECT * FROM nearest_street_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

UPDATE osm_polygon
  SET (city) = (SELECT * FROM nearest_point_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

--Streets
UPDATE osm_linestring
  SET (city) = (SELECT * FROM nearest_poly_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

UPDATE osm_linestring
  SET (city) = (SELECT * FROM nearest_street_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

UPDATE osm_linestring
  SET (city) = (SELECT * FROM nearest_point_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

--Points
UPDATE osm_point
  SET (city) = (SELECT * FROM nearest_poly_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

UPDATE osm_point
  SET (city) = (SELECT * FROM nearest_street_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;

UPDATE osm_point
  SET (city) = (SELECT * FROM nearest_point_get_city(geometry))
WHERE city IS NULL
	  AND place_rank > 16;