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


## Prerequisites

`docker compose` or `docker-compose` is required if you want to deploy via the yaml files.

### Install `docker-compose-plugin`

1. Add Docker’s GPG key

```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc
```
2. Add Docker repository

```
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

3. Install Compose plugin

```
sudo apt update && sudo apt install docker-compose-plugin
```

4. Verify

```
docker compose version
```

### Alternative (quick manual install)

If you don’t want to touch repos, you can install the binary directly:

    mkdir -p ~/.docker/cli-plugins/
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose

    docker compose version


### Install `docker-compose` (Legacy)

Please download latest docker-compose.

    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

You can face the issue below, as docker compose V1 is deprecated and incompatible with newer urllib3.

    TypeError: HTTPConnection.request() got an unexpected keyword argument 'chunked'

## Example (DBs use private IP and accessible via nginx)

You can test with command:

    docker compose -f mariadb-cluster-setup.yaml up -d

When all containsers are running, there is a nginx container running with nginx-galera.conf to expose the mariadb cluster.

    # docker compose -f mariadb-cluster-setup.yaml ps
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

    # mysql -h 127.0.0.1 -P13306 -uroot -pcloudstack -e 'show variables like "%version"';
    mysql: [Warning] Using a password on the command line interface can be insecure.
    +---------------------------------+----------------------------+
    | Variable_name                   | Value                      |
    +---------------------------------+----------------------------+
    | protocol_version                | 10                         |
    | tls_version                     | TLSv1.2,TLSv1.3            |
    | version                         | 12.2.2-MariaDB-ubu2404-log |
    | wsrep_patch_version             | wsrep_26.22                |
    | wsrep_provider_evs_version      | 1                          |
    | wsrep_provider_gmcast_version   | 0                          |
    | wsrep_provider_pc_version       | 0                          |
    | wsrep_provider_protonet_version | 0                          |
    +---------------------------------+----------------------------+

## Example (DBs use public IPs which are directly accessible)

You can test with command:

    docker compose -f mariadb-cluster-setup-macvlan.yaml up -d

When all containsers are running, 

    # docker compose -f mariadb-cluster-setup-macvlan.yaml ps
                Name                Command       State       Ports
    ---------------------------------------------------------------
    docker-mariadb-cluster_db01_1   /init.sh   Up (healthy)        
    docker-mariadb-cluster_db02_1   /init.sh   Up (healthy)        
    docker-mariadb-cluster_db03_1   /init.sh   Up    

The IPs are accessible, except the container host

    # mysql -h 10.0.33.53 -P3306 -uroot -pcloudstack -e "show status where variable_name in ('wsrep_cluster_status', 'wsrep_incoming_addresses','wsrep_local_state_comment');"
    mysql: [Warning] Using a password on the command line interface can be insecure.
    +---------------------------+---------------------------------------------------+
    | Variable_name             | Value                                             |
    +---------------------------+---------------------------------------------------+
    | wsrep_local_state_comment | Synced                                            |
    | wsrep_incoming_addresses  | 10.0.33.53:3306,10.0.35.200:3306,10.0.33.212:3306 |
    | wsrep_cluster_status      | Primary                                           |
    +---------------------------+---------------------------------------------------+

To access the service from the container host,

    ip link add host-nic link eth0 type macvlan mode bridge
    ip addr add 10.0.33.6/20 dev host-nic (only if the host IP is in different range as container IP)
    ip link set host-nic up
    ip route add 10.0.33.53/32 dev host-nic

## Releases

    v1.0        Ubuntu 18.04 and Mariadb 10.4
    v1.1        Ubuntu 20.04 and Mariadb 10.5.8
    v1.2        Ubuntu 20.04 and Mariadb 10.5.12
    v1.3        Ubuntu 22.04 and Mariadb 11.3.2
    v1.4        Ubuntu 24.04 and Mariadb 11.7.2
    v1.5        Ubuntu 24.04 and Mariadb 12.2.2
