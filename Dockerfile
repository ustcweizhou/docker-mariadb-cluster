FROM        ubuntu:18.04
MAINTAINER  Wei Zhou <w.zhou@global.leaseweb.com>

ENV         DEBIAN_FRONTEND noninteractive

RUN         apt update -qq && \
            apt upgrade -y && \
            apt install -y curl iproute2 net-tools

RUN         groupadd -r mysql && useradd -r -g mysql mysql && \
            mkdir -p /var/run/mysqld && \
            chown mysql:mysql /var/run/mysqld

RUN         curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash && \
            apt update -qq && \
            apt install -y mariadb-server mariadb-client && \
            apt install -y galera-arbitrator-4 galera-4

COPY        conf/ /etc/mysql/conf.d/

EXPOSE      3306 4444 4567 4568

ENTRYPOINT  ["mysqld"]
