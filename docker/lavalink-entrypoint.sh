#!/bin/sh
set -eu

metadata_url="https://maven.lavalink.dev/releases/dev/lavalink/youtube/youtube-plugin/maven-metadata.xml"
latest_version="$(curl --fail --silent --show-error --location "$metadata_url" \
  | sed -n 's|.*<release>\([^<]*\)</release>.*|\1|p' \
  | head -n 1 || true)"

config_file="application.yml"
if printf '%s' "$latest_version" | grep -Eq '^[0-9][0-9A-Za-z.+-]*$'; then
  config_file="$(mktemp /tmp/lavalink-application.XXXXXX.yml)"
  sed "s|youtube-plugin:[^\"]*|youtube-plugin:${latest_version}|" application.yml > "$config_file"
  printf '%s\n' "Using youtube-plugin ${latest_version}."
else
  printf '%s\n' "Could not resolve the latest youtube-plugin version; using application.yml."
fi

exec java -jar Lavalink.jar --spring.config.additional-location="file:${config_file}"
