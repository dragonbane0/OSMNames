DROP FUNCTION IF EXISTS get_final_display_name(TEXT, TEXT[], TEXT, TEXT, TEXT, TEXT, TEXT);
CREATE FUNCTION get_final_display_name(displayName TEXT, displayNameAttachments TEXT[], class TEXT, streetName TEXT, houseNumberSingle TEXT, postCode TEXT, city TEXT)
RETURNS TEXT AS $$
DECLARE
  finalDisplayNameTags HSTORE;
  finalDisplayNameArray TEXT[];
  finalStreetName TEXT;
  finalDisplayName TEXT;
BEGIN
  finalDisplayNameArray := displayNameAttachments;

  IF class = 'transport' IS FALSE THEN

    IF city IS NOT NULL AND city = '' IS FALSE THEN
	  finalDisplayNameArray := array_prepend(city, finalDisplayNameArray); 
	  finalDisplayNameArray := array_prepend('16', finalDisplayNameArray);
    END IF;

    IF postCode IS NOT NULL AND postCode = '' IS FALSE THEN
	  finalDisplayNameArray := array_prepend(postCode, finalDisplayNameArray); 
	  finalDisplayNameArray := array_prepend('21', finalDisplayNameArray); --rank of 21 is kept here for correct naming order
    END IF;

    IF streetName IS NOT NULL AND streetName = '' IS FALSE THEN
      finalStreetName := streetName;
	  IF houseNumberSingle IS NOT NULL AND houseNumberSingle = '' IS FALSE THEN
   	    finalStreetName := finalStreetName || ' ' || houseNumberSingle;
      END IF;

	  finalDisplayNameArray := array_prepend(finalStreetName, finalDisplayNameArray); 
	  finalDisplayNameArray := array_prepend('26', finalDisplayNameArray);
    END IF;

  END IF;

  finalDisplayNameTags := hstore(finalDisplayNameArray);

  SELECT array_agg(value)
  FROM 
  (
    SELECT *
	FROM 
    (
	  SELECT DISTINCT ON (value) key, value FROM
	  each(finalDisplayNameTags)
    ) AS Sub1
	ORDER BY key::INTEGER DESC
  ) AS Sub2
  INTO finalDisplayNameArray;

  finalDisplayNameArray := array_remove(finalDisplayNameArray, displayName);
  finalDisplayNameArray := array_prepend(displayName, finalDisplayNameArray);	

  finalDisplayName := array_to_string(finalDisplayNameArray, ', ');
  finalDisplayName := regexp_replace(finalDisplayName, ',+$', '', 'g'); --Removes trailing commas just in case

  IF finalDisplayName = '' THEN
    finalDisplayName = NULL;
  END IF;
  
  RETURN finalDisplayName;
END;
$$
LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS get_country_name(VARCHAR);
CREATE FUNCTION get_country_name(country_code_in VARCHAR(2)) returns TEXT as $$
  SELECT COALESCE(name -> 'name:de',
                  name -> 'name',
                  name -> 'name:en',
                  name -> 'name:fr',
                  name -> 'name:es',
                  name -> 'name:ru',
                  name -> 'name:zh')
          FROM country_name WHERE country_code = country_code_in;
$$ LANGUAGE 'sql' IMMUTABLE;


DROP FUNCTION IF EXISTS get_housenumbers(BIGINT);
CREATE FUNCTION get_housenumbers(osm_id_in BIGINT) RETURNS TEXT AS $$
  SELECT string_agg(housenumber, ', ' ORDER BY housenumber ASC)
    FROM osm_housenumber
    WHERE street_id = osm_id_in;
$$ LANGUAGE 'sql' IMMUTABLE;


DROP FUNCTION IF EXISTS get_bounding_box(GEOMETRY, TEXT, INTEGER);
CREATE FUNCTION get_bounding_box(geom GEOMETRY, country_code TEXT, admin_level INTEGER)
RETURNS DECIMAL[] AS $$
DECLARE
  bounding_box DECIMAL[];
  shifted_geom GEOMETRY;
  original_geom_length DECIMAL;
  shifted_geom_length DECIMAL;
  x_min DECIMAL;
  x_max DECIMAL;
BEGIN
  -- manually set bounding box for some countries
  IF admin_level = 2 AND lower(country_code) = 'fr' THEN
    bounding_box := ARRAY[-5.225,41.333,9.55,51.2];
  ELSIF admin_level = 2 AND lower(country_code) = 'nl' THEN
    bounding_box := ARRAY[3.133,50.75,7.217,53.683];
  ELSE
    geom := ST_Transform(geom, 4326);
    shifted_geom := ST_ShiftLongitude(geom);
    original_geom_length := ST_XMAX(geom) - ST_XMIN(geom);
    shifted_geom_length := ST_XMAX(shifted_geom) - ST_XMIN(shifted_geom);

    -- if shifted geometry is less wide then original geometry,
    -- use the shifted geometry to create the bounding box (see #94)
    IF original_geom_length > shifted_geom_length THEN
      -- the cast to geography coerces the bounding box in range [-180, 180]
      geom = shifted_geom::geography;

      -- if the max x > 180 after the cast, the geometry still crossed the anti merdian
      -- which need to be handled specially (this results in a bounding box where
      -- the east longitude is smaller then the west longitude, e.g. for the United States)
      IF st_xmax(shifted_geom) >= 180 AND st_xmin(shifted_geom) < 180 THEN
        x_min = st_xmin(shifted_geom);
        x_max = st_xmax(shifted_geom) - 360;
      END IF;
    END IF;

    bounding_box := ARRAY[
                          round(COALESCE(x_min, ST_XMIN(geom)::numeric), 7),
                          round(ST_YMIN(geom)::numeric, 7),
                          round(COALESCE(x_max, ST_XMAX(geom)::numeric), 7),
                          round(ST_YMAX(geom)::numeric, 7)
                          ];
  END IF;
  return bounding_box;
END;
$$
LANGUAGE plpgsql IMMUTABLE;
