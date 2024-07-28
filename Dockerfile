# From latest elixir version
# First build the app
FROM elixir:1.17 as builder

RUN apt-get update && apt-get install -y openssl

# Ensure mix is in prod mode
ENV MIX_ENV=prod

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
FROM elixir:1.15 AS runtime

# Install openssl
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y openssl \
    libtinfo-dev \
    ffmpeg \
    pipx


# Copy over the build artifact from the previous step and create a non root user
RUN useradd o2m
# yt-dlp search for a home directory
RUN mkdir -p /home/o2m/
RUN chown -R o2m:o2m /home/o2m/

RUN mkdir -p /srv/o2m/dets
RUN chown -R o2m:o2m /srv/o2m/dets

WORKDIR /opt/o2m

COPY --from=builder /opt/o2m/_build .
RUN chown -R o2m:o2m ./prod

USER o2m

# Install latest yt-dlp from github
RUN pipx install yt-dlp

ENV PATH="${HOME}/.local/bin:${PATH}" 

# default arg
CMD ["start"]

# default command
ENTRYPOINT ["./prod/rel/o2m/bin/o2m"]
