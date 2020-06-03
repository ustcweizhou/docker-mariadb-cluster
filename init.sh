#!/bin/bash
set -e

IP=$(hostname --ip-address | cut -d" " -f1)
HOSTNAME=$(hostname -s)

INIT_SQL="/init.sql"
INIT_LOG="/init.log"
ln -sf /proc/$$/fd/1 $INIT_LOG

if [ -z "$CHECK_MAX_RETRIES" ];then
    CHECK_MAX_RETRIES=60
fi

if [ -z "$CHECK_INTERVAL" ];then
    CHECK_INTERVAL=1
fi

check_server_status() {
    local server=$1
    set +e
    local status=$(mysql -h $server -uroot -p${DB_ROOT_PASSWORD} -NB -e "SHOW STATUS WHERE Variable_name='wsrep_local_state_comment'")
    if [ $? -ne 0 ];then
        echo "Failed to connect database on $server"
    else
        status=$(echo $status | awk '{print $2}')
        if [ "$status" != "Synced" ];then
            echo "Database server $server is not Synced but $status"
        fi
    fi
    set -e
}

wait_for_server_to_be_up() {
    local server=$1
    local retry=$CHECK_MAX_RETRIES
    echo -n "====== Checking server $server status " >>$INIT_LOG
    while [ $retry -gt 0 ];do
        echo -n "." >>$INIT_LOG
        status=$(check_server_status $server)
        if [ -z "$status" ];then
            echo " Done ======" >>$INIT_LOG
            break
        fi
        let retry=retry-1
        sleep $CHECK_INTERVAL
    done
    if [ $retry -eq 0 ];then
        echo " timeout. Exiting  ======" >>$INIT_LOG
        exit 1
    fi
}
mkdir -p /var/log/mysql
chown -R mysql:mysql /var/lib/mysql /var/log/mysql

if [ -z "$CLUSTER_ADDRESS" ];then
    echo "Missing CLUSTER_ADDRESS" >&2
    exit 1
else
    sed -i "s|^wsrep_cluster_address =.*|wsrep_cluster_address = '${CLUSTER_ADDRESS}'|g" /etc/mysql/conf.d/90-galera.cnf
    sed -i "s|^wsrep_node_address =.*|wsrep_node_address = ${IP}|g" /etc/mysql/conf.d/90-galera.cnf
    sed -i "s|^wsrep_node_incoming_address =.*|wsrep_node_incoming_address = ${IP}|g" /etc/mysql/conf.d/90-galera.cnf
    sed -i "s|^wsrep_node_name =.*|wsrep_node_name = ${HOSTNAME}|g" /etc/mysql/conf.d/90-galera.cnf
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

master_server=
is_master_server=true
new_cluster=true
hosts=$(echo $CLUSTER_ADDRESS | rev | cut -d '/' -f1 | rev | tr "," " ")
if [ ! -z "$hosts" ];then
    for host in $hosts;do
        if [ -z "$master_server" ];then
            master_server=$host     # master server is the first server in CLUSTER_ADDRESS
            if [ "$master_server" != "$IP" ] && [ "$master_server" != "$HOSTNAME" ];then
                is_master_server=false
            fi
        fi
        status=$(check_server_status $host)
        if [ -z "$status" ];then
            new_cluster=false
            break
        fi
    done
fi

cmd="mysqld"
if [ "$new_cluster" = "true" ];then
    if [ "$is_master_server" = "true" ];then
        cmd+=" --wsrep-new-cluster"
    else
        wait_for_server_to_be_up $master_server
    fi
fi

if [ ! -d "/var/lib/mysql/mysql" ];then
    echo "====== Installing mysql from scratch ======" >>$INIT_LOG
    mysql_install_db --datadir="/var/lib/mysql/" --user=mysql
    if [ "$new_cluster" = "true" ];then
        cmd+=" --init-file=$INIT_SQL"
    fi
elif [ "$new_cluster" = "true" ] && [ -f "/var/lib/mysql/grastate.dat" ] && [ "$is_master_server" = "true" ];then
    echo "====== Starting existing mariadb cluster ======" >>$INIT_LOG
    sed -i "s|^safe_to_bootstrap: 0|safe_to_bootstrap: 1|g" /var/lib/mysql/grastate.dat
    echo "====== Updated safe_to_bootstrap to 1 in /var/lib/mysql/grastate.dat ======" >>$INIT_LOG
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

echo "====== Executing command: $cmd ======" >>$INIT_LOG
$cmd
