DROP TYPE IF EXISTS parentInfo CASCADE;
CREATE TYPE parentInfo AS (
  country_code VARCHAR(2),
  state        TEXT,
  county       TEXT,
  city         TEXT,
  postCode     TEXT,
  displayName  TEXT
);
