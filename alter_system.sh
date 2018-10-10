#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

function alter_system() {
    echo "Altering System parameters"
    PGUSER="$POSTGRES_USER" psql --dbname="$POSTGRES_DB" <<-EOSQL
    alter system set max_connections = '20';
    alter system set shared_buffers = '1GB';
    alter system set effective_cache_size = '3GB';
    alter system set maintenance_work_mem = '256MB';
    alter system set checkpoint_completion_target = '0.7';
    alter system set wal_buffers = '16MB';
    alter system set default_statistics_target = '100';
    alter system set random_page_cost = '1.1';
    alter system set effective_io_concurrency = '200';
    alter system set work_mem = '52428kB';
    alter system set min_wal_size = '1GB';
    alter system set max_wal_size = '2GB';
    alter system set max_worker_processes = '2';
    alter system set max_parallel_workers_per_gather = '1';
    alter system set max_parallel_workers = '2';
EOSQL
}

alter_system