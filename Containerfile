# SPDX-License-Identifier: GPL-3.0-or-later
#
# Targets (--target):
#   defenestraos                      desktop, AMD/Intel
#   defenestraos-nvidia               desktop, NVIDIA closed (GTX 10xx+)
#   defenestraos-nvidia-open          desktop, NVIDIA open (RTX 20xx+)
#   defenestraos-deck             handheld/deck, AMD/Intel
#   defenestraos-deck-nvidia      handheld/deck, NVIDIA closed
#   defenestraos-deck-nvidia-open handheld/deck, NVIDIA open

ARG BASE_TAG="${BASE_TAG:-stable}"

ARG BASE_DESKTOP="${BASE_DESKTOP:-ghcr.io/ublue-os/bazzite-gnome:${BASE_TAG}}"
ARG BASE_DESKTOP_NVIDIA="${BASE_DESKTOP_NVIDIA:-ghcr.io/ublue-os/bazzite-gnome-nvidia:${BASE_TAG}}"
ARG BASE_DESKTOP_NVIDIA_OPEN="${BASE_DESKTOP_NVIDIA_OPEN:-ghcr.io/ublue-os/bazzite-gnome-nvidia-open:${BASE_TAG}}"
ARG BASE_DECK="${BASE_DECK:-ghcr.io/ublue-os/bazzite-deck-gnome:${BASE_TAG}}"
ARG BASE_DECK_NVIDIA="${BASE_DECK_NVIDIA:-ghcr.io/ublue-os/bazzite-deck-nvidia-gnome:${BASE_TAG}}"
ARG BASE_DECK_NVIDIA_OPEN="${BASE_DECK_NVIDIA_OPEN:-ghcr.io/ublue-os/bazzite-deck-nvidia-open-gnome:${BASE_TAG}}"

FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY cosign.pub cosign-backup.pub /

FROM ${BASE_DESKTOP} AS defenestraos

ARG IMAGE_NAME="defenestraos"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="desktop"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-defenestraOS}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_BRANCH="${IMAGE_BRANCH}" \
    IMAGE_VARIANT="${IMAGE_VARIANT}" \
    VERSION_TAG="${VERSION_TAG}" \
    VERSION_PRETTY="${VERSION_PRETTY}" \
    /ctx/build_files/build.sh

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint

FROM ${BASE_DESKTOP_NVIDIA} AS defenestraos-nvidia

ARG IMAGE_NAME="defenestraos-nvidia"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="desktop-nvidia"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-defenestraOS NVIDIA}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_BRANCH="${IMAGE_BRANCH}" \
    IMAGE_VARIANT="${IMAGE_VARIANT}" \
    VERSION_TAG="${VERSION_TAG}" \
    VERSION_PRETTY="${VERSION_PRETTY}" \
    /ctx/build_files/build.sh

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint

FROM ${BASE_DESKTOP_NVIDIA_OPEN} AS defenestraos-nvidia-open

ARG IMAGE_NAME="defenestraos-nvidia-open"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="desktop-nvidia-open"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-defenestraOS NVIDIA Open}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_BRANCH="${IMAGE_BRANCH}" \
    IMAGE_VARIANT="${IMAGE_VARIANT}" \
    VERSION_TAG="${VERSION_TAG}" \
    VERSION_PRETTY="${VERSION_PRETTY}" \
    /ctx/build_files/build.sh

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint

FROM ${BASE_DECK} AS defenestraos-deck

ARG IMAGE_NAME="defenestraos-deck"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="deck"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-defenestraOS Handheld}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_BRANCH="${IMAGE_BRANCH}" \
    IMAGE_VARIANT="${IMAGE_VARIANT}" \
    VERSION_TAG="${VERSION_TAG}" \
    VERSION_PRETTY="${VERSION_PRETTY}" \
    /ctx/build_files/build.sh

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint

FROM ${BASE_DECK_NVIDIA} AS defenestraos-deck-nvidia

ARG IMAGE_NAME="defenestraos-deck-nvidia"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="deck-nvidia"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-defenestraOS Handheld NVIDIA}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_BRANCH="${IMAGE_BRANCH}" \
    IMAGE_VARIANT="${IMAGE_VARIANT}" \
    VERSION_TAG="${VERSION_TAG}" \
    VERSION_PRETTY="${VERSION_PRETTY}" \
    /ctx/build_files/build.sh

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint

FROM ${BASE_DECK_NVIDIA_OPEN} AS defenestraos-deck-nvidia-open

ARG IMAGE_NAME="defenestraos-deck-nvidia-open"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="deck-nvidia-open"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-defenestraOS Handheld NVIDIA Open}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_BRANCH="${IMAGE_BRANCH}" \
    IMAGE_VARIANT="${IMAGE_VARIANT}" \
    VERSION_TAG="${VERSION_TAG}" \
    VERSION_PRETTY="${VERSION_PRETTY}" \
    /ctx/build_files/build.sh

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint
