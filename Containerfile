# =============================================================================
# DefenestraOS Container Build
#
# Based on Bazzite images — inherits gaming kernel, drivers, and gaming stack.
# We strip bazzite branding/onboarding and overlay defenestra identity.
#
# Targets (select with --target):
#   defenestraos                      — desktop, AMD/Intel
#   defenestraos-nvidia               — desktop, NVIDIA closed (GTX 10xx+)
#   defenestraos-nvidia-open          — desktop, NVIDIA open (RTX 20xx+)
#   defenestraos-handheld             — handheld/deck, AMD/Intel
#   defenestraos-handheld-nvidia      — handheld/deck, NVIDIA closed
#   defenestraos-handheld-nvidia-open — handheld/deck, NVIDIA open
# =============================================================================

ARG BASE_TAG="${BASE_TAG:-stable}"

ARG BASE_DESKTOP="${BASE_DESKTOP:-ghcr.io/ublue-os/bazzite-gnome:${BASE_TAG}}"
ARG BASE_DESKTOP_NVIDIA="${BASE_DESKTOP_NVIDIA:-ghcr.io/ublue-os/bazzite-gnome-nvidia:${BASE_TAG}}"
ARG BASE_DESKTOP_NVIDIA_OPEN="${BASE_DESKTOP_NVIDIA_OPEN:-ghcr.io/ublue-os/bazzite-gnome-nvidia-open:${BASE_TAG}}"
ARG BASE_HANDHELD="${BASE_HANDHELD:-ghcr.io/ublue-os/bazzite-deck-gnome:${BASE_TAG}}"
ARG BASE_HANDHELD_NVIDIA="${BASE_HANDHELD_NVIDIA:-ghcr.io/ublue-os/bazzite-deck-gnome-nvidia:${BASE_TAG}}"
ARG BASE_HANDHELD_NVIDIA_OPEN="${BASE_HANDHELD_NVIDIA_OPEN:-ghcr.io/ublue-os/bazzite-deck-gnome-nvidia-open:${BASE_TAG}}"

# Build context
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

# =============================================================================
# DESKTOP — AMD/Intel
# =============================================================================

FROM ${BASE_DESKTOP} AS defenestraos

ARG IMAGE_NAME="defenestraos"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="desktop"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-DefenestraOS}"

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

# =============================================================================
# DESKTOP — NVIDIA closed
# =============================================================================

FROM ${BASE_DESKTOP_NVIDIA} AS defenestraos-nvidia

ARG IMAGE_NAME="defenestraos-nvidia"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="desktop-nvidia"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-DefenestraOS NVIDIA}"

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

# =============================================================================
# DESKTOP — NVIDIA open
# =============================================================================

FROM ${BASE_DESKTOP_NVIDIA_OPEN} AS defenestraos-nvidia-open

ARG IMAGE_NAME="defenestraos-nvidia-open"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="desktop-nvidia-open"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-DefenestraOS NVIDIA Open}"

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

# =============================================================================
# HANDHELD — AMD/Intel
# =============================================================================

FROM ${BASE_HANDHELD} AS defenestraos-handheld

ARG IMAGE_NAME="defenestraos-handheld"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="handheld"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-DefenestraOS Handheld}"

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

# =============================================================================
# HANDHELD — NVIDIA closed
# =============================================================================

FROM ${BASE_HANDHELD_NVIDIA} AS defenestraos-handheld-nvidia

ARG IMAGE_NAME="defenestraos-handheld-nvidia"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="handheld-nvidia"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-DefenestraOS Handheld NVIDIA}"

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

# =============================================================================
# HANDHELD — NVIDIA open
# =============================================================================

FROM ${BASE_HANDHELD_NVIDIA_OPEN} AS defenestraos-handheld-nvidia-open

ARG IMAGE_NAME="defenestraos-handheld-nvidia-open"
ARG IMAGE_VENDOR="defenestra"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG IMAGE_VARIANT="handheld-nvidia-open"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY:-DefenestraOS Handheld NVIDIA Open}"

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
