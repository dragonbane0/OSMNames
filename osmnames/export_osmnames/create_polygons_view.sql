DROP MATERIALIZED VIEW IF EXISTS mv_polygons;
CREATE MATERIALIZED VIEW mv_polygons AS
SELECT
  name,
  alternative_names,
  CASE WHEN osm_id > 0 THEN 'way' ELSE 'relation' END AS osm_type,
  abs(osm_id)::VARCHAR as osm_id,
  class,
  type,
  round(ST_X(ST_PointOnSurface(ST_Buffer(ST_Transform(geometry, 4326), 0.0)))::numeric::numeric, 7) AS lon,
  round(ST_Y(ST_PointOnSurface(ST_Buffer(ST_Transform(geometry, 4326), 0.0)))::numeric::numeric, 7) AS lat,
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
  bounding_box[1] AS west,
  bounding_box[2] AS south,
  bounding_box[3] AS east,
  bounding_box[4] AS north,
  NULLIF(wikidata, '') AS wikidata,
  NULLIF(wikipedia, '') AS wikipedia,
  NULL::VARCHAR AS housenumbers
FROM
  osm_polygon,
  get_bounding_box(geometry, countryCode, admin_level) AS bounding_box,
  get_final_display_name(displayName, displayNameAttachments, class, streetName, houseNumberSingle, postCode) AS displayNameFinal;
