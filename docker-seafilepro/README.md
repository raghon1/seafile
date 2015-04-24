# Seafile 4 for Docker

[Seafile](http://www.seafile.com/) is a "next-generation open source cloud storage
with advanced features on file syncing, privacy protection and teamwork".

This Dockerfile is based on JensErat/docker-seafile

This Dockerfile install an environment to run seafile.
Seafile will be autoconfigurated with the default parameters and running at the container startup

## Setup Db
You can use a mysql/mariadb container or any other database you already have installed.

Run it

    docker run -d --name="mariadb" guilhem30/mariadb

Get mariadb root password

    docker logs mariadb 

## Setup Seafile

The image install seafile and configure it according to the default environment variables in the Dockerfile and the variables you give it at runtime. 

Seafile can create his own databases or it can be installed with existing (empty) ones.

In any case **you need to provide at least the IP adress of the interface to listen on and some user/password info**

If you don't choose a password it will be randomly generated if possible and written to "docker logs"

###Auto create databases with seafile
If you want seafile to automatically create databases for you, you need to provide him the root user and password.

You might also want to provide a seahub admin email if you don't want the default one

example :

    docker run -d --name "myseafile" \
      -p 10001:10001 -p 12001:12001 -p 8000:8000 -p 8082:8082 \
      --link mariadb:mysql-container \
      -e "CCNET_IP=192.168.0.100" -e "MYSQL_ROOT_USER=dataadmin" \ 
      -e "MYSQL_ROOT_PASSWORD=rootpass" -e "SEAHUB_ADMIN_EMAIL=seafileadmin@yourdomain.com" \
      guilhem30/seafile 
      

###Existing databases (no root password needed)
If you want to use existing databases you need to provide the mysql user and password for those databases and their names (or the script will look for the default ones).

:warning: Databases must be empty at seafile installation or it will crash!

For example, you could use

    docker run -d --name "myseafile" \
      -p 10001:10001 -p 12001:12001 -p 8000:8000 -p 8082:8082 \
      --link mariadb:mysql-container \
      -e "CCNET_IP=192.168.0.100" -e "EXISTING_DB=true" -e "SEAHUB_ADMIN_EMAIL=seafileadmin@yourdomain.com" \
      -e "MYSQL_USER=myseafileuser" -e "MYSQL_PASSWORD=myseafilepass" \
      guilhem30/seafile   
      
##Auto-configure Nginx
Run nginx first with a volume where you want to store static files

    docker run -d --name nginx -p 80:80 -p 443:443 -v /opt/seafile/nginx guilhem30/nginx
    
then run seafile with --volumes-from to allow it to create the configuration file, ssl certificates and copy his static files

For SEAFILE_IP you can use the static ip of the container (not very flexible), the host ip if you expose ports, or some dns discovery like skydock/skydns (used in this example)

     docker run -d --name "myseafile"  -e fcgi=true -e autonginx=true -e "CCNET_IP=myfiles.mydomain.com" \
     -e "MYSQL_ROOT_USER=root" -e "MYSQL_ROOT_PASSWORD=rootpass" \
     -e "SEAHUB_ADMIN_EMAIL=admin@yourdomain.com" -e "SEAFILE_IP=myseafile.seafile.dev.docker" \
     -e "MYSQL_HOST=mydatabase.mariadb.dev.docker" --volumes-from nginx seafile

just restart nginx after each new seafile container launch to make it reload his configuration

    docker restart nginx
    
##All configuration options      

All the environment variables and their default values

    autostart					true
    autoconf					true
    autonginx                   false
    fcgi						false
    CCNET_IP
    SEAFILE_IP
    CCNET_PORT					10001
    CCNET_NAME 			    	my-seafile
    SEAFILE_PORT				12001
    FILESERVER_PORT			    8082
    EXISTING_DB 				false
    MYSQL_HOST 		    		mysql-container
    MYSQL_PORT 			    	3306
    MYSQL_ROOT_USER 			root
    MYSQL_ROOT_PASSWORD
    MYSQL_USER 			    	seafileuser
    MYSQL_PASSWORD 		    	randomly generated
    SEAHUB_ADMIN_EMAIL 	    	seaadmin@sea.com
    SEAHUB_ADMIN_PASSWORD   	randomly generated
    CCNET_DB_NAME 		    	ccnet-db
    SEAFILE_DB_NAME 			seafile-db
    SEAHUB_DB_NAME		    	seahub-db
    SEAHUB_PORT 				8000
    STATIC_FILES_DIR            /opt/seafile/nginx/


## Updates and Maintenance

The Seafile directory is stored in the permanent volume `/opt/seafile`. To update the base system or the seafile running options, just stop the container, update the image using `docker pull guilhem30/seafile` and run another container with autoconf disabled and the --volumes-from option

example :

    docker run -d --name "myseafile2" \
     -p 10001:10001 -p 12001:12001 -p 8000:8000 -p 8082:8082 \
     --link mariadb:mysql-container \ 
     -e "autoconf=false" \
     --volumes-from myseafile \
     guilhem30/seafile   

To update Seafile, you should start another container with the same volume mounted but also autostart disabled and then follow the normal upgrade process described in the [Seafile upgrade manual](http://manual.seafile.com/deploy/upgrade.html). 

example :

    docker run -d --name "seafileUpdater" \
     -p 10001:10001 -p 12001:12001 -p 8000:8000 -p 8082:8082 \
     --link mariadb:mysql-container \ 
     -e "autoconf=false" \
     -e "autostart=false" \
     --volumes-from myseafile \
     guilhem30/seafile   
