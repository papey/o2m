# From latest elixir version
# First build the app
FROM elixir:1.9 as builder

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
FROM elixir:1.9 AS runtime

# Install openssl
RUN apt-get update && apt-get install -y openssl libtinfo-dev

# Copy over the build artifact from the previous step and create a non root user
RUN useradd o2m
RUN mkdir /opt/o2m
WORKDIR /opt/o2m

COPY --from=builder /opt/o2m/_build .
RUN chown -R o2m: ./prod

USER o2m

CMD ["./prod/rel/o2m/bin/o2m", "start"]


