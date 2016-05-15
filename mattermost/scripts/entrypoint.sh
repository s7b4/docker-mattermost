#! /bin/bash

set -e

# Check env
if [ -z "$POSTGRES_DB" -o -z "$POSTGRES_USER" -o -z "$POSTGRES_PASSWORD" ]; then
	echo >&2 'error: missing POSTGRES_* environment variables'
	exit 1
fi

# Data
if [ ! -d $APP_HOME/data ]; then
	mkdir $APP_HOME/data
	chown $APP_USER $APP_HOME/data
fi

# Logs
if [ ! -d $APP_HOME/logs ]; then
	mkdir $APP_HOME/logs
	chown $APP_USER $APP_HOME/logs
fi

# Configuration
if [ ! -f $APP_HOME/config.json ]; then
	# Copie du template
	cp /opt/mattermost/config/config.json $APP_HOME/config.json
	chown $APP_USER $APP_HOME/config.json

	cat $APP_HOME/config.json | \
		jq ".LogSettings.FileLocation = \"$APP_HOME/logs/app.log\"" | \
		jq ".FileSettings.Directory = \"$APP_HOME/data\"" | \
		jq ".ComplianceSettings.Directory = \"$APP_HOME/data\"" \
		> $APP_HOME/config.json.tmp && \
	mv $APP_HOME/config.json.tmp $APP_HOME/config.json
fi

# Force db settings
cat $APP_HOME/config.json | \
	jq ".SqlSettings.DriverName = \"postgres\"" | \
 	jq ".SqlSettings.DataSource = \"postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB?sslmode=disable&connect_timeout=10\"" \
	> $APP_HOME/config.json.tmp && \
mv $APP_HOME/config.json.tmp $APP_HOME/config.json

# Waiting for db
echo "Waiting for db ..."
while ! nc -w 1 db 5432 2>/dev/null
do
  sleep 5
done

cd "/opt/mattermost/bin"
exec gosu "$APP_USER" ./platform --config="$APP_HOME/config.json"