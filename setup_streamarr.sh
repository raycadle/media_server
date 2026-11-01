#!/usr/bin/env bash

create_setup () {
  if [[ ! -d "${DOWNLOADS}" ]]; then
    mkdir -p "${DOWNLOADS}"
  fi
  mkdir -p "${APPS}"/{qbittorrent,jellyfin,sonarr,radarr,prowlarr}/config
}

create_streamarr () {
  podman pod create \
    --name=streamarr \
    -p 8080:8080 `#qbittorrent webui` \
    -p 6881:6881 `#qbittorrent extra` \
    -p 6881:6881/udp `#qbittorrent extra` \
    -p 8096:8096 `#jellyfin http` \
    -p 8920:8920 `#jellyfin https` \
    -p 7359:7359/udp `#jellyfin network discovery` \
    -p 1900:1900/udp `#jellyfin DNLA discovery` \
    -p 8989:8989 `#sonarr` \
    -p 7878:7878 `#radarr` \
    -p 9696:9696 `#prowlarr`
}

create_qbittorrent () {
  podman create \
    --pod=streamarr \
    --name=qbittorrent \
    --label io.containers.autoupdate=registry \
    -e PUID="${PUID}" \
    -e PGID="${PGID}" \
    -e TZ="${TZ}" \
    -e WEBUI_PORT=8080 \
    -e TORRENTING_PORT=6881 \
    -v "${APPS}"/qbittorrent/config:/config:Z \
    -v "${DOWNLOADS}":/downloads:z \
    lscr.io/linuxserver/qbittorrent:latest
}

create_jellyfin () {
  podman create \
    --pod=streamarr \
    --name=jellyfin \
    --label io.containers.autoupdate=registry \
    -e PUID="${PUID}" \
    -e PGID="${PGID}" \
    -e TZ="${TZ}" \
    --device=/dev/dri:/dev/dri \
    -v "${APPS}"/jellyfin/config:/config:Z \
    -v "${SHOWS}":/data/shows:z \
    -v "${MOVIES}":/data/movies:z \
    lscr.io/linuxserver/jellyfin:latest
}

create_sonarr () {
  podman create \
    --pod=streamarr \
    --name=sonarr \
    --label io.containers.autoupdate=registry \
    -e PUID="${PUID}" \
    -e PGID="${PGID}" \
    -e TZ="${TZ}" \
    -v "${APPS}"/sonarr/config:/config:Z \
    -v "${SHOWS}":/shows:z \
    -v "${DOWNLOADS}":/downloads:z \
    lscr.io/linuxserver/sonarr:latest
}

create_radarr () {
  podman create \
    --pod=streamarr \
    --name=radarr \
    --label io.containers.autoupdate=registry \
    -e PUID="${PUID}" \
    -e PGID="${PGID}" \
    -e TZ="${TZ}" \
    -v "${APPS}"/radarr/config:/config:Z \
    -v "${MOVIES}":/movies:z \
    -v "${DOWNLOADS}":/downloads:z \
    lscr.io/linuxserver/radarr:latest
}

create_prowlarr () {
  podman create \
    --pod=streamarr \
    --name=prowlarr \
    --label io.containers.autoupdate=registry \
    -e PUID="${PUID}" \
    -e PGID="${PGID}" \
    -e TZ="${TZ}" \
    -v "${APPS}"/prowlarr/config:/config:Z \
    lscr.io/linuxserver/prowlarr:latest
}

create_service () {
  service_dir="${HOME}/.config/systemd/user"

  mkdir -p "${service_dir}"
  
  podman pod start streamarr && \
  podman generate systemd \
    --new \
    --files \
    --name streamarr && \
  mv *.service "${service_dir}/"

  podman pod stop streamarr && podman pod rm streamarr

  systemctl --user daemon-reload
}

run_apps () {
  systemctl --user enable --now pod-streamarr.service
}

main () {
  PUID=0
  PGID=0
  TZ=America/Belize
  APPS="${HOME}"/apps
  SHOWS=/mnt/media/shows
  MOVIES=/mnt/media/movies
  DOWNLOADS=/mnt/media/downloads

  create_setup
  create_streamarr
  create_qbittorrent
  create_jellyfin
  create_sonarr
  create_radarr
  create_prowlarr
  create_service
  run_apps
}

main
