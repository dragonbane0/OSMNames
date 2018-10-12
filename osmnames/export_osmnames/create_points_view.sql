DROP MATERIALIZED VIEW IF EXISTS mv_points;
CREATE MATERIALIZED VIEW mv_points AS
SELECT
  name,
  alternative_names,
  'node'::TEXT as osm_type,
  osm_id::VARCHAR AS osm_id,
  class,
  type,
  round(ST_X(ST_Transform(geometry, 4326))::numeric, 7) AS lon,
  round(ST_Y(ST_Transform(geometry, 4326))::numeric, 7) AS lat,
  place_rank,
  importance,
  streetName::TEXT AS street,
  postCode::TEXT AS postal_code,
  city,
  county,
  state,
  get_country_name(countryCode) AS country,
  countryCode::VARCHAR(2) AS country_code,
  displayNameFinal AS display_name,
  round(ST_XMIN(ST_Transform(geometry, 4326))::numeric, 7) AS west,
  round(ST_YMIN(ST_Transform(geometry, 4326))::numeric, 7) AS south,
  round(ST_XMAX(ST_Transform(geometry, 4326))::numeric, 7) AS east,
  round(ST_YMAX(ST_Transform(geometry, 4326))::numeric, 7) AS north,
  NULLIF(wikidata, '') AS wikidata,
  NULLIF(wikipedia, '') AS wikipedia,
  NULL::VARCHAR AS housenumbers
FROM
  osm_point,
  get_final_display_name(displayName, displayNameAttachments, class, streetName, houseNumberSingle, postCode, city) AS displayNameFinal
WHERE
  linked IS FALSE;
