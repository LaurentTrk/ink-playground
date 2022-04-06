################################################################################
# Setup
################################################################################

# Start from a rust base image
FROM rust:slim-buster as builder

# Set the current directory
WORKDIR /app

# Copy everthing that is not dockerignored to the image
COPY . .

################################################################################
# Install Yarn & NPM dependencies
################################################################################

RUN apt-get --yes update
RUN apt-get --yes upgrade
RUN apt-get install --yes apt-utils curl npm pkg-config
RUN curl -sL https://deb.nodesource.com/setup_17.x | bash -
RUN apt-get install -y nodejs
RUN npm install --global yarn
RUN make install

################################################################################
# Prepare
################################################################################

RUN rustup toolchain install nightly-2021-11-04
RUN rustup toolchain install stable
RUN rustup component add rust-src --toolchain nightly-2021-11-04-x86_64-unknown-linux-gnu
RUN curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

################################################################################
# Build
################################################################################

RUN rustup default stable
RUN cargo clean --manifest-path crates/rust_analyzer_wasm/Cargo.toml
RUN cd crates/rust_analyzer_wasm && wasm-pack build --target web --out-dir ../../packages/ink-editor/pkg
RUN make generate-bindings
RUN make generate-change-json

RUN rustup default nightly

ARG COMPILE_URL=/compile
ARG GIST_LOAD_URL=/gist/load
ARG GIST_CREATE_URL=/gist/create

RUN make playground-build

RUN rustup default stable
RUN make backend-build-prod

FROM debian:slim-buster

COPY --from=builder /app/target/release/backend /app/target/release/backend
COPY --from=builder /app/packages/playground/dist /app/packages/playground/dist


################################################################################
# Install Docker
# see: https://www.how2shout.com/linux/install-docker-ce-on-debian-11-bullseye-linux/
################################################################################

RUN apt-get update && apt-get install --yes \
    apt-transport-https ca-certificates curl gnupg lsb-release 

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

RUN echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list >/dev/null

RUN apt-get --yes update

RUN apt-get --yes install docker-ce docker-ce-cli containerd.io



################################################################################
# Provide Start
################################################################################

COPY sysbox/on-start.sh /usr/bin
RUN chmod +x /usr/bin/on-start.sh

################################################################################
# Entrypoint
################################################################################

ENTRYPOINT [ "on-start.sh" ]
