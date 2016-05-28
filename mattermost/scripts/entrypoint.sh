#! /bin/bash

set -e

# Check env
if [ -z "$POSTGRES_DB" -o -z "$POSTGRES_USER" -o -z "$POSTGRES_PASSWORD" ]; then
	echo >&2 'error: missing POSTGRES_* environment variables'
	exit 1
fi

# DB
: ${PG_HOST:="db"}
: ${PG_PORT:="5432"}

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
		jq ".ComplianceSettings.Directory = \"$APP_HOME/data\"" | \
		jq ".LogSettings.FileLocation = \"$APP_HOME/logs/app.log\"" | \
		jq ".FileSettings.Directory = \"$APP_HOME/data\"" \
		> $APP_HOME/config/docker.json.tmp && \
	mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json

	# Generate salt
	cat $APP_HOME/config/docker.json | \
		jq ".EmailSettings.InviteSalt = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" | \
		jq ".EmailSettings.PasswordResetSalt = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" | \
		jq ".FileSettings.PublicLinkSalt = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" | \
		jq ".SqlSettings.AtRestEncryptKey = \"$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)\"" \
		> $APP_HOME/config/docker.json.tmp && \
	mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json

fi

# Force db settings
cat $APP_HOME/config/docker.json | \
	jq ".SqlSettings.DriverName = \"postgres\"" | \
 	jq ".SqlSettings.DataSource = \"postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$PG_HOST:$PG_PORT/$POSTGRES_DB?sslmode=disable&connect_timeout=10\"" \
	> $APP_HOME/config/docker.json.tmp && \
mv $APP_HOME/config/docker.json.tmp $APP_HOME/config/docker.json

# Config RW
chown $APP_USER:$APP_USER $APP_HOME/config/docker.json

# Waiting for db
echo "Waiting for db ..."
while ! nc -w 1 $PG_HOST $PG_PORT 1>/dev/null 2>&1
do
  sleep 5
done

cd "/opt/mattermost"
# Start
if [ ! -z "$@" ]; then
	# Custom command
	exec gosu "$APP_USER" $@
else
	# Default start
	exec gosu "$APP_USER" bin/platform --config="$APP_HOME/config/docker.json"
fi