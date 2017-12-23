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

