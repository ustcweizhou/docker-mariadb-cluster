# MariaDB Galera Cluster by Docker Swarm

This describes how to set up mariadb galera cluster by docker swarm. There are two modes:
- Single-server mode
- Multiple-servers mode

## 1. Prerequisites

### Run Docker in swarm mode
```
https://docs.docker.com/engine/swarm/swarm-mode/
```

### Join nodes to swarm (Required by Multiple-servers mode)
```
https://docs.docker.com/engine/swarm/join-nodes/
```
Add labels to swarm nodes
```
# docker node update --label-add role=infra01 node42
# docker node update --label-add role=infra02 node43
# docker node update --label-add role=infra03 node44
```

## 2. Modify ENV file

galera-cluster.env stores some database configurations. Data will be put to $DATA_DIR/$PROJECT/ folder on swarm nodes.

```
PROJECT=test
DATA_DIR=/root/docker/
DB_ROOT_PASSWORD=cloudstack
DB_MARIABACKUP_PASSWORD=cloudstack
```

## 3. Set up a Mariadb Galera cluster

### Load global variables
```
export $(cat galera-cluster.env) >/dev/null 2>&1
```

### Set up cluster in Single-server mode
All services will be running on same server.
```
docker stack deploy --compose-file=galera-cluster-s.yaml galera
```

### Set up cluster in Multiple-servers mode
```
docker stack deploy --compose-file=galera-cluster.yaml galera
```
Database services will be running on different swarm nodes.

    db01 -> server with label role=infra01
    db02 -> server with label role=infra02
    db03 -> server with label role=infra03

## Expectations

### docker services

```
# docker service ls
ID                  NAME                MODE                REPLICAS            IMAGE                                       PORTS
nvdvgc95h2tz        galera_db01         replicated          1/1                 ustcweizhou/mariadb-cluster:ubuntu18-10.4
zmftqcxxe2mw        galera_db02         replicated          1/1                 ustcweizhou/mariadb-cluster:ubuntu18-10.4
wr6gghkdrctd        galera_db03         replicated          1/1                 ustcweizhou/mariadb-cluster:ubuntu18-10.4
ri5jr1caz58i        galera_dbvip        replicated          1/1                 nginx:latest                                *:13306->3306/tcp
```

### services are running on different swarm nodes
```
# docker service ps galera_db01
ID                  NAME                IMAGE                                       NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
10c4u0b6mkdk        galera_db01.1       ustcweizhou/mariadb-cluster:ubuntu18-10.4   node42              Running             Running 36 minutes ago

# docker service ps galera_db02
ID                  NAME                IMAGE                                       NODE                DESIRED STATE       CURRENT STATE            ERROR                       PORTS
y6k6wlf8lo5h        galera_db02.1       ustcweizhou/mariadb-cluster:ubuntu18-10.4   node43              Running             Running 36 minutes ago

# docker service ps galera_db03
ID                  NAME                IMAGE                                       NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
yax7cbo415ee        galera_db03.1       ustcweizhou/mariadb-cluster:ubuntu18-10.4   node44              Running             Running 36 minutes ago

# docker service ps galera_dbvip
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
oi9cdv2vjjqu        galera_dbvip.1      nginx:latest        swarm-manager       Running             Running 36 minutes ago
```

### MariaDB status
```
# mysql -h 127.0.0.1 -P13306 -uroot -pcloudstack -e "show status where variable_name in ('wsrep_cluster_status', 'wsrep_incoming_addresses','wsrep_local_state_comment');"
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------------------+-----------------------------------------+
| Variable_name             | Value                                   |
+---------------------------+-----------------------------------------+
| wsrep_local_state_comment | Synced                                  |
| wsrep_incoming_addresses  | 192.168.10.3,192.168.10.9,192.168.10.14 |
| wsrep_cluster_status      | Primary                                 |
+---------------------------+-----------------------------------------+
```

