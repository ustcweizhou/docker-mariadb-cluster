#!/bin/bash
set -e

IP=$(hostname --ip-address | cut -d" " -f1)
INIT_SQL="/init.sql"

mkdir -p /var/log/mysql
chown -R mysql:mysql /var/lib/mysql /var/log/mysql

if [ -z "$CLUSTER_ADDRESS" ];then
    echo "Missing CLUSTER_ADDRESS" >&2
    exit 1
else
    sed -i "s|^wsrep_cluster_address =.*|wsrep_cluster_address = '${CLUSTER_ADDRESS}'|g" /etc/mysql/conf.d/90-galera.cnf
    sed -i "s|^wsrep_node_address =.*|wsrep_node_address =${IP}|g" /etc/mysql/conf.d/90-galera.cnf
fi

if [ -z "${DB_ROOT_PASSWORD}" ];then
    echo "Missing DB_ROOT_PASSWORD" >&2
    exit 1
fi

if [ -z "${DB_MARIABACKUP_PASSWORD}" ];then
    echo "Missing DB_MARIABACKUP_PASSWORD" >&2
    exit 1
else
    sed -i "s|^wsrep_sst_auth =.*|wsrep_sst_auth = mariabackup:${DB_MARIABACKUP_PASSWORD}|g" /etc/mysql/conf.d/90-galera.cnf
fi

cmd="mysqld"
if [ ! -d "/var/lib/mysql/mysql" ];then
    mysql_install_db --datadir="/var/lib/mysql/" --user=mysql
fi

if [ ! -f "$INIT_SQL" ];then
    cat >$INIT_SQL << EOF
DELETE FROM mysql.global_priv WHERE NOT (Host = 'localhost' AND User = 'mariadb.sys');
CREATE USER 'root'@'%' IDENTIFIED BY "${DB_ROOT_PASSWORD}";
GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
CREATE USER 'mariabackup'@'%' IDENTIFIED BY "${DB_MARIABACKUP_PASSWORD}";
GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'mariabackup'@'%';
FLUSH PRIVILEGES;
EOF
fi

action=$1
if [ "$action" = "new" ];then
    cmd+=" --wsrep-new-cluster"
    cmd+=" --init-file=$INIT_SQL"
fi

$cmd
