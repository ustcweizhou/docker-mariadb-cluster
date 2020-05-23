#!/bin/bash
set -e

IP=$(hostname --ip-address | cut -d" " -f1)

mkdir -p /var/lib/mysql/log
chown -R mysql:mysql /var/lib/mysql

if [ -z "$CLUSTER_ADDRESS" ];then
    echo "Missing CLUSTER_ADDRESS" >&2
    exit 1
else
    sed -i "s|^wsrep_cluster_address =.*|wsrep_cluster_address = '${CLUSTER_ADDRESS}'|g" /etc/mysql/conf.d/90-galera.cnf
    sed -i "s|^wsrep_node_address =.*|wsrep_node_address =${IP}|g" /etc/mysql/conf.d/90-galera.cnf
fi

if [ ! -d "/var/lib/mysql/mysql" ];then
    mysql_install_db --datadir="/var/lib/mysql/"
fi

cmd="mysqld"
action=$1
if [ "$action" = "new" ];then
    cmd+=" --default-authentication-plugin=mysql_native_password"
    cmd+=" --wsrep-new-cluster"

    if [ ! -f "/var/lib/mysql/init.sql" ];then
        cat >/var/lib/mysql/init.sql << "        EOF"
        CREATE USER 'mariabackup'@'%' IDENTIFIED BY 'mypassword';
        GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *. * TO 'mariabackup'@'%';
        FLUSH PRIVILEGES;
        EOF
        cmd+=" --init-file=/var/lib/mysql/init.sql"
    fi
fi

$cmd
