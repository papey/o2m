# From latest elixir version
# First build the app
FROM elixir:1.14 as builder

RUN apt-get update && apt-get install -y openssl

# Declare args
ARG REVISION
ARG RELEASE_TAG

# Ensure mix is in prod mode
ENV MIX_ENV=prod

# image-spec annotations using labels
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.source="https://github.com/papey/o2m"
LABEL org.opencontainers.image.revision=${GIT_COMMIT_SHA}
LABEL org.opencontainers.image.version=${RELEASE_TAG}
LABEL org.opencontainers.image.authors="Wilfried OLLIVIER"
LABEL org.opencontainers.image.title="o2m"
LABEL org.opencontainers.image.description="o2m runtime"
LABEL org.opencontainers.image.licences="Unlicense"

# Create src dir
RUN mkdir /opt/o2m

# Set working directory
WORKDIR /opt/o2m

# Deps first, optimizing layers
COPY mix.exs .
COPY mix.lock .

# Download deps
RUN mix local.hex --force && \
    mix local.rebar --force
RUN mix deps.get
RUN mix deps.compile

# Then code
COPY . .

# Release
RUN mix release

# App is build, setup runtime
FROM elixir:1.14 AS runtime

# Install openssl
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y openssl \
    libtinfo-dev \
    ffmpeg \
    python3 \
    python3-pip

# Install latest youtube-dl from pip
RUN pip3 install youtube-dl

# Copy over the build artifact from the previous step and create a non root user
RUN useradd o2m
# youtube-dl search for a home directory
RUN mkdir -p /home/o2m/
RUN chown -R o2m:o2m /home/o2m/

RUN mkdir -p /srv/o2m/dets
RUN chown -R o2m:o2m /srv/o2m/dets

WORKDIR /opt/o2m

COPY --from=builder /opt/o2m/_build .
RUN chown -R o2m:o2m ./prod

USER o2m

# default arg
CMD ["start"]

# default command
ENTRYPOINT ["./prod/rel/o2m/bin/o2m"]
