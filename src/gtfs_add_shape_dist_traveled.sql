 -- This script uses PostGIS to fill in the shape_dist_traveled field using stop and shape geometries. 
 -- It assumes that gtfs_tables_makespatial.sql has been run to build said geometries.

 -- Create a table that contains stop distances along trip patterns, assuming that a pattern consists of
 -- (a.route_id, direction_id, shape_id)
 -- this is far more efficient than doing the geometry processing on every row in stop_times
begin;
drop table if exists gtfs_stop_distances_along_shape;

CREATE TABLE gtfs_stop_distances_along_shape AS
SELECT a.route_id, direction_id, shape_id, stop_sequence, stop_id, round(cast(st_line_locate_point(route_geom,stop_geom) as numeric),3) AS pct_along_shape, 
	st_line_locate_point(route_geom,stop_geom) * st_length_spheroid(route_geom, 'SPHEROID["GRS_1980",6378137,298.257222101]') as dist_along_shape
FROM gtfs_distinct_patterns a
LEFT JOIN (SELECT the_geom AS route_geom, shape_id FROM gtfs_shape_geoms) c USING (shape_id)
LEFT JOIN (SELECT the_geom AS stop_geom, stop_id FROM gtfs_stops) d USING (stop_id); 
commit;

 -- Use this table to create a second gtfs_stop_times table, using key above
begin;
drop table if exists gtfs_stop_times2;
create table gtfs_stop_times2 as
select st.trip_id, st.arrival_time, st.departure_time, st.stop_id, st.stop_sequence,st.stop_headsign, 
	pickup_type ,  drop_off_type ,  a.dist_along_shape as shape_dist_traveled,   timepoint,  arrival_time_seconds ,  departure_time_seconds 
from gtfs_stop_distances_along_shape a
join gtfs_stop_times st on st.stop_id = a.stop_id
join gtfs_trips t on st.trip_id = t.trip_id
where
a.route_id = t.route_id
	and a.direction_id= t.direction_id
	and a.shape_id = t.shape_id 
	and st.stop_sequence = a.stop_sequence
	and a.stop_id = st.stop_id;
commit;

-- drop and replace the existing stop_times table
begin;
drop table if exists gtfs_stop_times;
alter table gtfs_stop_times2 rename to gtfs_stop_times;
commit;
