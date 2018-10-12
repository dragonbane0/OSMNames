CREATE OR REPLACE FUNCTION determine_class(type TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN CASE
    WHEN type IN ('motorway','motorway_link','trunk','trunk_link','primary','primary_link','secondary','secondary_link','tertiary','tertiary_link',
                  'unclassified','residential','road','living_street','raceway','construction','track','service','path','cycleway',
                  'steps','bridleway','footway','corridor','crossing','pedestrian') THEN 'highway'
    WHEN type IN ('river','riverbank','stream','canal','drain','ditch') THEN 'waterway'
    WHEN type IN ('mountain_range','water','bay','desert','peak','volcano','hill') THEN 'natural'
    WHEN type IN ('administrative', 'postal_code') THEN 'boundary'
    WHEN type IN ('city','borough','suburb','quarter','neighbourhood','town','village','hamlet',
                  'island','ocean','sea','continent','country','state') THEN 'place'
    WHEN type IN ('residential','reservoir') THEN 'landuse'
    WHEN type IN ('aerodrome') THEN 'aeroway'
    WHEN type IN ('station','halt','bus_stop','tram_stop','ferry_terminal') THEN 'transport'
    WHEN type IN ('camp_site','guest_house','hostel','hotel','motel') THEN 'nightstay'
    WHEN type IN ('clinic','dentist','doctors','hospital') THEN 'healthcare'
    WHEN type IN ('cinema','nightclub','planetarium','theatre','zoo','theme_park','museum','gallery','attraction','aquarium','viewpoint') THEN 'attraction'
    WHEN type IN ('bar','cafe','restaurant') THEN 'food'
    WHEN type IN ('college','university') THEN 'education'
    WHEN type IN ('mall','department_store') THEN 'shopping'
	WHEN type LIKE '%motorway%' THEN 'highway'
	WHEN type LIKE '%trunk%' THEN 'highway'
	WHEN type LIKE '%primary%' THEN 'highway'
	WHEN type LIKE '%secondary%' THEN 'highway'
	WHEN type LIKE '%tertiary%' THEN 'highway'
	WHEN type LIKE '%unclassified%' THEN 'highway'
	WHEN type LIKE '%residential%' THEN 'highway'
	WHEN type LIKE '%road%' THEN 'highway'
	WHEN type LIKE '%living_street%' THEN 'highway'
	WHEN type LIKE '%raceway%' THEN 'highway'
	WHEN type LIKE '%construction%' THEN 'highway'
	WHEN type LIKE '%track%' THEN 'highway'
	WHEN type LIKE '%service%' THEN 'highway'
	WHEN type LIKE '%path%' THEN 'highway'
	WHEN type LIKE '%cycleway%' THEN 'highway'
	WHEN type LIKE '%steps%' THEN 'highway'
	WHEN type LIKE '%bridleway%' THEN 'highway'
	WHEN type LIKE '%footway%' THEN 'highway'
	WHEN type LIKE '%corridor%' THEN 'highway'
	WHEN type LIKE '%crossing%' THEN 'highway'
    ELSE 'multiple'
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS get_parent_info(BIGINT, TEXT, TEXT, INTEGER, VARCHAR, HSTORE);
CREATE FUNCTION get_parent_info(id BIGINT, name TEXT, type TEXT, rank INTEGER, wikipedia VARCHAR, all_tags HSTORE)
RETURNS TABLE(displayName TEXT, displayNameAttachments TEXT[], class TEXT, importance DOUBLE PRECISION, streetName TEXT, houseNumberSingle TEXT, postCode TEXT, city TEXT, county TEXT, state TEXT, countryCode VARCHAR(2)) AS $$
DECLARE
  current_name TEXT;
  current_rank INTEGER;
  current_id BIGINT;
  current_type TEXT;
  current_class TEXT;
  current_country_code VARCHAR(2);
  city_rank INTEGER := 16;
  county_rank INTEGER := 10;
BEGIN
  current_id := id;
  displayName := name;
  class := determine_class(type);

  WHILE current_id IS NOT NULL LOOP
    SELECT p.name, p.place_rank, p.parent_id, p.type, p.country_code
    FROM osm_polygon AS p
    WHERE p.id = current_id
    INTO current_name, current_rank, current_id, current_type, current_country_code;

	current_class := determine_class(current_type);

	IF current_class = 'highway' THEN
	  streetName := current_name;
	END IF;

    IF current_country_code IS NOT NULL THEN
      countryCode := current_country_code;
    END IF;

    IF class = 'transport' THEN
	  IF displayName = '' THEN
        displayName := current_name;
      ELSIF current_rank <= 18 OR current_type IN ('village','hamlet') THEN
        EXIT WHEN current_rank = 4;
		displayNameAttachments := array_append(displayNameAttachments, to_char(current_rank, '999'));
		displayNameAttachments := array_append(displayNameAttachments, current_name);
      END IF;      
    ELSE
	  IF displayName = '' THEN
        displayName := current_name;
      ELSIF current_class = 'highway' IS FALSE AND current_rank <> 21 THEN
        EXIT WHEN current_rank = 4;
        displayNameAttachments := array_append(displayNameAttachments, to_char(current_rank, '999'));
        displayNameAttachments := array_append(displayNameAttachments, current_name);
      END IF;
    END IF;	

    CONTINUE WHEN current_type IN ('water', 'bay', 'desert', 'reservoir', 'pedestrian');
    EXIT WHEN current_rank = 4;

    IF current_rank = 21 THEN
      postCode := current_name;
    ELSIF current_rank BETWEEN 16 AND 22 THEN --This is safe as postal_code is handled explicitly beforehand
      city := current_name;
      city_rank := current_rank;
    ELSIF (current_rank BETWEEN 10 AND city_rank) AND (county IS NULL) THEN
      county := current_name;
      county_rank := current_rank;
    ELSIF (current_rank BETWEEN 6 AND county_rank) THEN
      state := current_name;
    END IF;
  END LOOP;

  --get feature importance
  importance := get_place_importance(rank, wikipedia, countryCode);

  --get feature postal_code from tags if available
  IF postCode = '' IS NOT FALSE AND rank > 20 THEN
    SELECT COALESCE(
                  all_tags -> 'postal_code',
                  all_tags -> 'addr:postcode')
    INTO postCode;
  END IF;

  --get feature street and housenumber from tags if available
  IF class = 'highway' THEN
    streetName := displayName;
  END IF;

  IF streetName = '' IS NOT FALSE AND rank > 21 THEN
    SELECT COALESCE(
                  all_tags -> 'addr:street')
    INTO streetName;

    SELECT COALESCE(
                  all_tags -> 'addr:housenumber')
    INTO houseNumberSingle;
  END IF;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


DROP FUNCTION IF EXISTS get_place_importance(INTEGER, VARCHAR, VARCHAR(2));
CREATE FUNCTION get_place_importance(place_rank INTEGER, wikipedia VARCHAR, country_code VARCHAR(2)) 
RETURNS DOUBLE PRECISION as $$
DECLARE
  wiki_article_title TEXT;
  wiki_article_language VARCHAR;
  country_language_code VARCHAR(2);
  result double precision;
BEGIN
  wiki_article_title := replace(split_part(wikipedia, ':', 2),' ','_');
  wiki_article_language := split_part(wikipedia, ':', 1);

  country_language_code := get_country_language_code(country_code);

  SELECT importance
  FROM wikipedia_article
  WHERE title = wiki_article_title
  ORDER BY (language = wiki_article_language) DESC,
           (language = country_language_code) DESC,
           (language = 'en') DESC,
           importance DESC
  LIMIT 1
  INTO result;

  IF result IS NOT NULL THEN
    RETURN result;
  ELSE
    RETURN 0.75-(place_rank::double precision/40);
  END IF;
END;
$$
LANGUAGE plpgsql IMMUTABLE;


DROP FUNCTION IF EXISTS get_country_language_code(VARCHAR);
CREATE FUNCTION get_country_language_code(country_code_in VARCHAR(2)) RETURNS VARCHAR(2) AS $$
  SELECT lower(country_default_language_code)
         FROM country_name
         WHERE country_code = country_code_in LIMIT 1;
$$ LANGUAGE 'sql' IMMUTABLE;


UPDATE osm_linestring SET (displayName, displayNameAttachments, class, importance, streetName, houseNumberSingle, postCode, city, county, state, countryCode) = (SELECT * FROM get_parent_info(parent_id, name, type, place_rank, wikipedia, all_tags));
UPDATE osm_polygon SET (displayName, displayNameAttachments, class, importance, streetName, houseNumberSingle, postCode, city, county, state, countryCode) = (SELECT * FROM get_parent_info(id, '', type, place_rank, wikipedia, all_tags));
UPDATE osm_point SET (displayName, displayNameAttachments, class, importance, streetName, houseNumberSingle, postCode, city, county, state, countryCode) = (SELECT * FROM get_parent_info(parent_id, name, type, place_rank, wikipedia, all_tags));

