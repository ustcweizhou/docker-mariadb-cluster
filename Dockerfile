FROM        ubuntu:20.04
MAINTAINER  Wei Zhou <ustcweizhou@gmail.com>

ENV         DEBIAN_FRONTEND noninteractive

RUN         apt update -qq && \
            apt upgrade -y && \
            apt install -y curl iproute2 net-tools iputils-ping

RUN         groupadd -r mysql && useradd -r -g mysql mysql && \
            mkdir -p /var/run/mysqld && \
            chown mysql:mysql /var/run/mysqld

RUN         curl -LsS https://downloads.mariadb.com/MariaDB/mariadb-keyring-2019.gpg -o /etc/apt/trusted.gpg.d/mariadb-keyring-2019.gpg && \
            echo "deb http://sfo1.mirrors.digitalocean.com/mariadb/repo/10.5/ubuntu focal main" > /etc/apt/sources.list.d/mariadb.list && \
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
