DROP FUNCTION IF EXISTS array_remove_element_starting_from_index(anyarray, TEXT, INTEGER);
CREATE FUNCTION array_remove_element_starting_from_index(arr anyarray, element TEXT, index INTEGER)
RETURNS anyarray AS $$
BEGIN
 IF array_length(arr, 1) < index THEN
   RETURN arr;
 END IF;

 RETURN arr[1:index-1] || array_remove(arr[index:2147483647], element);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP FUNCTION IF EXISTS get_names(TEXT, TEXT, HSTORE);
CREATE FUNCTION get_names(current_name TEXT, type TEXT, all_tags HSTORE)
RETURNS TABLE(name TEXT, alternative_names_string TEXT) AS $$
DECLARE
  accepted_name_tags TEXT[] := ARRAY['name:left','name:right','int_name','loc_name','nat_name',
                                     'official_name','old_name','reg_name','short_name','alt_name'];
  alternative_names TEXT[];

  alternative_names_set_order TEXT[];

  modified_tags HSTORE;
BEGIN

  SELECT array_agg(DISTINCT(all_tags -> key))
    FROM unnest(akeys(all_tags)) AS key
    WHERE key LIKE 'name:__' OR key = ANY(accepted_name_tags)
  INTO alternative_names;

  name := current_name;
  IF name = '' IS NOT FALSE THEN
    SELECT COALESCE(
                  all_tags -> 'name',
                  all_tags -> 'name:en',
                  all_tags -> 'name:fr',                  
                  all_tags -> 'name:es',
				  all_tags -> 'name:de',
                  alternative_names[1])
      INTO name;
  END IF;

  --Special name handling for type boundary=postal_code
  IF name = '' IS NOT FALSE AND type = 'postal_code' THEN
    SELECT COALESCE(
                  all_tags -> 'postal_code',
                  all_tags -> 'addr:postcode')
      INTO name;
  END IF;

  name := regexp_replace(name, E'\\s+', ' ', 'g');

  --Ensure all language tags are present, else attach them with placeholder
  modified_tags := all_tags;

  IF exist(modified_tags,'name') IS FALSE THEN
	modified_tags := modified_tags || 'name=>!NOT_DEFINED!'::hstore;
  END IF;

  IF exist(modified_tags,'name:en') IS FALSE THEN
	modified_tags := modified_tags || 'name:en=>!NOT_DEFINED!'::hstore;
  END IF;

  IF exist(modified_tags,'name:fr') IS FALSE THEN
	modified_tags := modified_tags || 'name:fr=>!NOT_DEFINED!'::hstore;
  END IF;

  IF exist(modified_tags,'name:es') IS FALSE THEN
	modified_tags := modified_tags || 'name:es=>!NOT_DEFINED!'::hstore;
  END IF;

  IF exist(modified_tags,'name:de') IS FALSE THEN
	modified_tags := modified_tags || 'name:de=>!NOT_DEFINED!'::hstore;
  END IF;

  SELECT array_agg(modified_tags -> key)
    FROM 
	(
	SELECT * FROM
	unnest(akeys(modified_tags)) AS key
	ORDER BY 
	CASE WHEN(
	  key = 'name:en')
	  THEN 1
	  WHEN(key = 'name:fr') 
	  THEN 2
      WHEN(key = 'name:es') 
	  THEN 3
      WHEN(key = 'name:de') 
	  THEN 4
	  WHEN(key = 'name') 
	  THEN 5
      ELSE 6
	  END
    ) AS Sub
	WHERE key IN ('name','name:en','name:fr','name:es','name:de') OR key = ANY(accepted_name_tags)
    INTO alternative_names_set_order;

  alternative_names_set_order := array_replace(alternative_names_set_order, '!NOT_DEFINED!', '');
  alternative_names_set_order := array_replace(alternative_names_set_order, name, '');

  --After all the set languages uniqueness no longer has to be guaranteed
  IF array_length(alternative_names_set_order, 1) >= 6 THEN
    alternative_names_set_order := array_remove_element_starting_from_index(alternative_names_set_order, alternative_names_set_order[1], 6);
    alternative_names_set_order := array_remove_element_starting_from_index(alternative_names_set_order, alternative_names_set_order[2], 6);
    alternative_names_set_order := array_remove_element_starting_from_index(alternative_names_set_order, alternative_names_set_order[3], 6);
    alternative_names_set_order := array_remove_element_starting_from_index(alternative_names_set_order, alternative_names_set_order[4], 6);
    alternative_names_set_order := array_remove_element_starting_from_index(alternative_names_set_order, alternative_names_set_order[5], 6);
  END IF;

  alternative_names_string := array_to_string(alternative_names_set_order, ',');
  alternative_names_string := regexp_replace(alternative_names_string, E'\\s+', ' ', 'g');
  alternative_names_string := regexp_replace(alternative_names_string, ',+$', '', 'g'); --Removes trailing commas

  IF alternative_names_string = '' THEN
    alternative_names_string = NULL;
  END IF;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


UPDATE osm_linestring SET (name, alternative_names) = (SELECT * FROM get_names(name, type, all_tags));
UPDATE osm_polygon SET (name, alternative_names) = (SELECT * FROM get_names(name, type, all_tags));
UPDATE osm_point SET (name, alternative_names) = (SELECT * FROM get_names(name, type, all_tags));
