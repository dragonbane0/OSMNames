# OSM Names
Database of geographic place names with hierarchy and bounding boxes from
OpenStreetMap for full text search downloadable for free: http://osmnames.org

This is a fork, please check out the original project page here, all credit goes to them: https://github.com/OSMNames/OSMNames

## Changes in my fork

- Many new OSM types are being tracked to include airports, train stations, bus stops, hotels, restaurants, touristic attractions for a more rich user experience, see the mapping file for more details
- Post codes are now tracked as well. Incomplete data is automatically filled in with the following approach:
  - postal_code boundaries are tracked (the feature will be named after the postal_code in your tsv) and each polygon, linestring or node where it makes sense will be attempted to be linked to such a boundary after retrieving the parental information
  - Additionally the tags from the feature are checked and the post code is possibly retrieved from tags such as addr:postcode
  - If the post code is still empty, it will attempt to find the next closest street/point/polygon that has a post code set and take that one for an approximation. The same approach is used to complete missing street names and city names
- German names are preferred over English (German target audience) and languages not useful for my needs are dropped (such as Russian)
- The alternative_names column is now populated in a predictable way, with a forced language order of EN, FR, ES, DE and finally native name. Alt names after this retain the random order and can thus still be used for a better autocomplete search. Missing languages before the end retain an empty comma in the column allowing your webserver to retrieve exactly the desired language you want (or detect whether a certain language is available)
- The information from the parents is now derived in an earlier seperate step. Country names are omitted from the display_name as my users select their country in an earlier step and thus already know which country they are looking at. Public transportation stations are only tagged with their own name and the city/state name. Assigning a postal code or suburbs to those is needless (in the display_name)
- For places addr:* tags will be checked and if available a precise street and/or housenumber will be added to the display_name
- Duplicate entries in the osm_point table that share the same name and are within 1000m of each other and share the same class will be dropped (such as multiple bus_stops on each side of the road)
- Fixed an annoyance where many streets would be assigned a "multiple" class value which results in the street column not being populated
- I omitted several columns from the final tsv data export that are of no use to my project
- Housenumbers in the housenumbers table are now also sorted by importance and grouped together by their street_id to avoid the cluttered nature it had before. The importance value is derived from the street the housenumbers are associated with
- The importance value is included in the housenumbers export while other needless columns are omitted. The order and naming of the columns has been adjusted to easily integrate with sphinxsearch which I use twice in my project (once for geoname searching, once for housenumber searching if the user selects a street, as well as reversed geocoding down to the exact housenumber)
- The final display_name is created in a more predictable way with duplicate words filtered out for better readability
