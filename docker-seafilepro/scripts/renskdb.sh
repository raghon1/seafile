#!/bin/bash
#

dbcon="mysql -sL -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASSWORD}"

for db in $($dbcon -e "show databases" | grep -v information_schema) ; do
        echo $db
        for table in $($dbcon -D$db -e "show tables") ; do
                echo $table
                $dbcon -D$db -e "drop table \`$table\`"
        done
done
