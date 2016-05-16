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
	chown $APP_USER:$APP_USER $APP_HOME/data
fi

# Logs
if [ ! -d $APP_HOME/logs ]; then
	mkdir $APP_HOME/logs
	chown $APP_USER:$APP_USER $APP_HOME/logs
fi

# Config
if [ ! -d $APP_HOME/config ]; then

	mkdir $APP_HOME/config
	chown $APP_USER:$APP_USER $APP_HOME/config

	# Copie du template
	cp /opt/mattermost/config/config.json $APP_HOME/config/docker.json

	cat $APP_HOME/config/docker.json | \
		jq ".LogSettings.FileLocation = \"$APP_HOME/logs/app.log\"" | \
		jq ".FileSettings.Directory = \"$APP_HOME/data\"" \
		> $APP_HOME/config/docker.json.tmp && \
	mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json
fi

# Force db settings
cat $APP_HOME/config/docker.json | \
	jq ".SqlSettings.DriverName = \"postgres\"" | \
 	jq ".SqlSettings.DataSource = \"postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB?sslmode=disable&connect_timeout=10\"" \
	> $APP_HOME/config/docker.json.tmp && \
mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json

# Config RW
chown $APP_USER:$APP_USER $APP_HOME/config/docker.json

# Waiting for db
echo "Waiting for db ..."
while ! nc -w 1 db 5432 2>/dev/null
do
  sleep 5
done

cd "/opt/mattermost"
exec gosu "$APP_USER" bin/platform --config="$APP_HOME/config/docker.json"