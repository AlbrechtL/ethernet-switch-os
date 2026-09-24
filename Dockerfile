# The development container: the upstream kas image plus what this project
# needs beyond a plain bitbake build.
#
#   docker build -t ethernet-switch-os/kas:5.5 - < Dockerfile
#   export KAS_CONTAINER_IMAGE=ethernet-switch-os/kas:5.5
#
# The tag matches the vendored kas-container script -- kas refuses to run
# against an image whose version does not match.
FROM ghcr.io/siemens/kas/kas:5.5

# - device-tree-compiler, u-boot-tools, mtd-utils: read back what the BSP
#   produces -- "dtc -I dtb" on a device tree, "mkimage -l" on the uImage,
#   the JFFS2 tools on a dump of the data partition.
# - docker-cli is the client without the daemon (Debian's docker.io is the
#   daemon and drags in containerd). It drives rtl838x-qemu, which runs QEMU
#   in a container of its own. That needs /var/run/docker.sock mounted, which
#   the devcontainer does and a kas-container build deliberately does not.
# - The rest is for working in a shell rather than for the build itself.
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash-completion \
        ca-certificates \
        curl \
        device-tree-compiler \
        docker-cli \
        file \
        git-lfs \
        iputils-ping \
        less \
        mtd-utils \
        tree \
        u-boot-tools \
        vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# A host Rust toolchain for clixon-switch-rs: "cargo check" and clippy while
# editing, and "cargo test" for the tests that run on the build host. bitbake
# builds the plugin with its own cross toolchain and ignores this one, and
# the crate list in clixon-switch-crates.inc is regenerated with
# "bitbake -c update_crates clixon-switch", not with cargo. rustup honours
# the rust-toolchain.toml in the checkout.
ENV RUSTUP_HOME=/opt/rust/rustup \
    CARGO_HOME=/opt/rust/cargo \
    PATH=/opt/rust/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --profile minimal \
                     --component clippy --component rustfmt && \
    chmod -R a+rwX "${CARGO_HOME}" "${RUSTUP_HOME}" && \
    # A login shell (what a VS Code terminal opens) rebuilds PATH from
    # /etc/profile, which drops the ENV above and, for a non-root user, the
    # sbin directories where mtd-utils puts mkfs.jffs2 and friends.
    printf 'export PATH=%s:$PATH:/usr/sbin:/sbin\n' "${CARGO_HOME}/bin" \
        > /etc/profile.d/ethernet-switch-os.sh

USER builder
