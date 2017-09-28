# Mattermost
FROM debian:stretch
LABEL maintainer = "s7b4 <baron.stephane@gmail.com>"

ENV GOSU_VERSION=1.10 \
	APP_VERSION=4.2.0 \
	APP_USER=mattermost

ENV APP_HOME=/home/$APP_USER

# set user/group IDs
RUN groupadd -r "$APP_USER" --gid=999 && useradd -m -r -g "$APP_USER" --uid=999 "$APP_USER"

# Base
RUN apt-get update \
	&& apt-get install --no-install-recommends --yes \
		ca-certificates \
		curl \
		jq \
		netcat \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Gosu
RUN curl -o /usr/local/sbin/gosu -sSL "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
	&& chmod +x /usr/local/sbin/gosu

# Install Mattermost
RUN mkdir -p /opt/mattermost \
	&& curl -s "https://releases.mattermost.com/$APP_VERSION/mattermost-team-$APP_VERSION-linux-$(dpkg --print-architecture | awk -F- '{ print $NF }').tar.gz" | \
	tar xzf - --directory /opt/mattermost --strip-components 1

COPY scripts/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 8065
VOLUME $APP_HOME