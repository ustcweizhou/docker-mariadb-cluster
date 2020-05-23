FROM        ubuntu:18.04
MAINTAINER  Wei Zhou <ustcweizhou@gmail.com>

ENV         DEBIAN_FRONTEND noninteractive

RUN         apt update -qq && \
            apt upgrade -y && \
            apt install -y curl iproute2 net-tools iputils-ping

RUN         groupadd -r mysql && useradd -r -g mysql mysql && \
            mkdir -p /var/run/mysqld && \
            chown mysql:mysql /var/run/mysqld

RUN         curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash && \
            apt update -qq && \
            apt install -y mariadb-server mariadb-client mariadb-backup && \
            apt install -y galera-arbitrator-4 galera-4 && \
            rm -rf /var/lib/mysql && \
            mkdir /var/lib/mysql

COPY        conf/ /etc/mysql/conf.d/
COPY        my.cnf /etc/mysql/my.cnf
COPY        init.sh /init.sh

EXPOSE      3306 4444 4567 4568

ENTRYPOINT  ["/init.sh"]
