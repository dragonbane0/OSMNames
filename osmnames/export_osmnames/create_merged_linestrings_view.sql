DROP MATERIALIZED VIEW IF EXISTS mv_merged_linestrings;
CREATE MATERIALIZED VIEW mv_merged_linestrings AS
SELECT
  name,
  alternative_names,
  'way'::TEXT as osm_type,
  osm_id::VARCHAR AS osm_id,
  class,
  type,
  round(ST_X(ST_PointOnSurface(ST_Transform(geometry, 4326)))::numeric, 7) AS lon,
  round(ST_Y(ST_PointOnSurface(ST_Transform(geometry, 4326)))::numeric, 7) AS lat,
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
  get_housenumbers(osm_id) AS housenumbers
FROM
  osm_merged_linestring,
  get_final_display_name(displayName, displayNameAttachments, class, streetName, houseNumberSingle, postCode) AS displayNameFinal;
