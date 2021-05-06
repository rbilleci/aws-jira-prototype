#!/bin/bash

## Update the dbconfig.xml to remove JIRA warning about validation query timeout
if [ -f /var/efs/dbconfig.xml ]; then
  if [ ! $(grep validation-query-timeout /var/efs/dbconfig.xml) ]; then
    sed -i 's/<\/jdbc-datasource>/    <validation-query-timeout>3<\/validation-query-timeout>\n<\/jdbc-datasource>/g' /var/efs/dbconfig.xml
  fi
fi
