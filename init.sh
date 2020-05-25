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

cmd="mysqld"
if [ ! -d "/var/lib/mysql/mysql" ];then
    mysql_install_db --datadir="/var/lib/mysql/" --auth-root-authentication-method=normal
    cmd+=" --init-file=$INIT_SQL"
fi

if [ ! -f "$INIT_SQL" ];then
    cat >$INIT_SQL << EOF
DELETE FROM mysql.user;
CREATE USER 'root'@'%' IDENTIFIED BY 'mypassword';
GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
CREATE USER 'mariabackup'@'%' IDENTIFIED BY 'mypassword';
GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'mariabackup'@'%';
FLUSH PRIVILEGES;
EOF
fi

action=$1
if [ "$action" = "new" ];then
#    cmd+=" --default-authentication-plugin=mysql_native_password"
    cmd+=" --wsrep-new-cluster"
fi

$cmd
