# zfsssic - zfs send snapshot incremental check 

This script send all snapshot for first to last incrementaly on a remote server and check if snapshot is done and transfered.  

* Usage: ./zfsssics.sh

## Set it up

Create an account for zfs transfert on booth end.  

~~~
root@serverA:~# pw useradd zfsssics -s /sbin/nologin
~~~

~~~
root@serverB:~# pw useradd zfsssics -s /sbin/nologin
~~~

## xymon test

#### Dependencies 

* bash
* sudo

#### Configuration

* add this to : /usr/local/www/xymon/client/etc/clientlaunch.cfg

~~~
[zfsssic]
        ENVFILE $XYMONCLIENTHOME/etc/xymonclient.cfg
        CMD /usr/local/www/xymon/client/ext/xymon_zfsssic
        LOGFILE /usr/local/www/xymon/client/logs/xymon_zfsssic.log
        INTERVAL 25m
~~~

* add this to : /usr/local/etc/sudoers

~~~
xymon ALL=NOPASSWD:/root/bin/zfs-check-backup.sh -Hlrnb1
~~~
