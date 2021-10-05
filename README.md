# MariaDB Galera Cluster in Docker Containers

This repository maintains the Dockerfile and scripts to build MariaDB Galera Cluster in Docker Containers.

## What does it do

Dockerfile : 

    1. Build from official docker container
    2. Install mariadb-server mariadb-client mariadb-backup and dependencies
    3. Copy files (conf/, my.cnf, init.sh)
    4. Set /init.sh as entrypoint

init.sh :

    1. Modify mysql config file based on environment variables.
    2. Check service in the cluster to see if this is a new cluster
    3. Install mysql from scratch, if mysql data is not found
    4. Updated safe_to_bootstrap to 1 in /var/lib/mysql/grastate.dat, if mysql data is found and this is a new cluster
    5. Start mysqld with different arguments.

## Docker image
 The docker image can be found at https://hub.docker.com/repository/docker/ustcweizhou/mariadb-cluster

## Example

You can test with command:

    docker-compose -f mariadb-cluster-setup.yaml up -d

If it does not work, please download latest docker-compose and try again.

    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

When all containsers are running, there is a nginx container running with nginx-galera.conf to expose the mariadb cluster.

    # docker-compose -f mariadb-cluster-setup.yaml ps
             Name                   Command             State                       Ports
    ------------------------------------------------------------------------------------------------------
    mariadb-cluster_db01_1    /init.sh               Up (healthy)   3306/tcp, 4444/tcp, 4567/tcp, 4568/tcp
    mariadb-cluster_db02_1    /init.sh               Up             3306/tcp, 4444/tcp, 4567/tcp, 4568/tcp
    mariadb-cluster_db03_1    /init.sh               Up             3306/tcp, 4444/tcp, 4567/tcp, 4568/tcp
    mariadb-cluster_dbvip_1   nginx -g daemon off;   Up             0.0.0.0:13306->3306/tcp, 80/tcp

    # mysql -h 127.0.0.1 -P13306 -uroot -pcloudstack -e "show status where variable_name in ('wsrep_cluster_status', 'wsrep_incoming_addresses','wsrep_local_state_comment');"
    +---------------------------+----------------------------------------+
    | Variable_name             | Value                                  |
    +---------------------------+----------------------------------------+
    | wsrep_local_state_comment | Synced                                 |
    | wsrep_incoming_addresses  | 172.16.10.11,172.16.10.12,172.16.10.13 |
    | wsrep_cluster_status      | Primary                                |
    +---------------------------+----------------------------------------+

## Releases

    v1.0        Ubuntu 18.04 and Mariadb 10.4
    v1.1        Ubuntu 20.04 and Mariadb 10.5.8
    v1.2        Ubuntu 20.04 and Mariadb 10.5.12
