# SPDX-License-Identifier: GPL-3.0-or-later
export image_name := env("IMAGE_NAME", "defenestraos")
export default_tag := env("DEFAULT_TAG", "latest")
export base_tag := env("BASE_TAG", "stable")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

# All available build targets
targets := "defenestraos defenestraos-nvidia defenestraos-nvidia-open defenestraos-handheld defenestraos-handheld-nvidia defenestraos-handheld-nvidia-open"

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Build a single variant. Examples:
#   just build                       # defenestraos (AMD/Intel desktop)
#   just build defenestraos-nvidia   # NVIDIA closed desktop
# just build defenestraos-handheld # handheld AMD/Intel
build $target=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    BUILD_ARGS=("--build-arg" "BASE_TAG={{ base_tag }}")
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    echo "Building target: ${target}"
    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --target "${target}" \
        --tag "localhost/${target}:${tag}" \
        .

# Build all variants
[group('Build')]
build-all $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    for target in {{ targets }}; do
        echo "=== Building ${target} ==="
        just build "${target}" "{{ tag }}"
    done

# Build live ISO payload container and generate ISO via Titanoboa
# Requires: the OS image must be built first (just build)
[group('Build Live ISO')]
build-live-iso $target=image_name $tag=default_tag: (_rootful_load_image target tag)
    #!/usr/bin/env bash
    set -euo pipefail

    PAYLOAD_TAG="localhost/${target}-live-payload:${tag}"
    BASE_IMAGE="localhost/${target}:${tag}"
    INSTALL_IMAGE="localhost/${target}:${tag}"

    echo "=== Building live ISO payload for ${target} ==="

    # Mount host container storage so the build can load the OS image
    # --no-cache because installer scripts change frequently during development
    sudo podman build \
        --no-cache \
        --cap-add sys_admin \
        --security-opt label=disable \
        -v /var/lib/containers/storage:/usr/lib/containers/storage:ro \
        --build-arg BASE_IMAGE="$BASE_IMAGE" \
        --build-arg INSTALL_IMAGE_PAYLOAD="$INSTALL_IMAGE" \
        -t "$PAYLOAD_TAG" \
        installer/

    if [[ ! -d .titanoboa ]]; then
        echo "=== Cloning Titanoboa ==="
        git clone -b revamp-pr https://github.com/Zeglius/titanoboa.git .titanoboa
    fi

    echo "=== Generating live ISO via Titanoboa ==="
    mkdir -p output
    sudo TITANOBOA_CTR_IMAGE="$PAYLOAD_TAG" \
         TITANOBOA_OUTPUT_DIR="$(pwd)/output" \
         ./.titanoboa/main.sh

    echo "=== ISO ready in output/ ==="

# Build only desktop variants (no handheld)
[group('Build')]
build-desktop $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    for target in defenestraos defenestraos-nvidia defenestraos-nvidia-open; do
        echo "=== Building ${target} ==="
        just build "${target}" "{{ tag }}"
    done

# BIB runs as root and reads from root podman storage. If the user built into
# their rootless storage, scp the image up to root; otherwise pull fresh.
_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Convert a container image to a bootable disk image (qcow2/raw/iso) via BIB.
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Build the container image then run BIB on it.
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtual Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('Build Virtual Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtual Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtual Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    image_file="output/${type}/disk.${type}"

    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtual Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtual Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from the Titanoboa live ISO
[group('Run Virtual Machine')]
run-vm-live-iso:
    #!/usr/bin/bash
    set -eoux pipefail

    iso_file=$(find output -maxdepth 1 -name "*.iso" -print -quit 2>/dev/null)
    if [[ -z "$iso_file" ]]; then
        echo "No live ISO found in output/. Run 'just build-live-iso' first."
        exit 1
    fi

    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run --rm --privileged \
        --pull=newer \
        --publish "127.0.0.1:${port}:8006" \
        --env "CPU_CORES=4" \
        --env "RAM_SIZE=8G" \
        --env "DISK_SIZE=64G" \
        --env "TPM=Y" \
        --env "GPU=Y" \
        --device=/dev/kvm \
        -v "${PWD}/${iso_file}:/boot.iso" \
        docker.io/qemux/qemu

# Run a virtual machine using systemd-vmspawn
[group('Run Virtual Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}

# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
