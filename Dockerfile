# The version of Alpine to use for the final image
# The `ALPINE_VERSION` should match the version used by the elixir:*-alpine image used below
ARG ALPINE_VERSION=3.17

FROM elixir:1.13.3-alpine AS builder

# The following are build arguments used to change variable parts of the image.
# The name of your application/release (required)
ARG APP_NAME
# The version of the application we are building (required)
ARG APP_VSN
# The environment to build with
ARG MIX_ENV=prod
# If you are using an umbrella project, you can change this
# argument to the directory the Phoenix app is in so that the assets
# can be built
ARG PHOENIX_SUBDIR=.

ENV APP_NAME=${APP_NAME} \
    APP_VSN=${APP_VSN}   \
    MIX_ENV=${MIX_ENV}   \
    APP_DIR=/opt/app

# By convention, /opt is typically used for applications
WORKDIR ${APP_DIR}

# This step installs all the build tools we'll need
RUN apk update              \
    && apk upgrade --no-cache  \
    && apk add --no-cache      \
    bash                  \
    make                  \
    build-base            \
    git            \
    && mix local.rebar --force \
    && mix local.hex --force

# This only copies what is needed to install and compile our deps
COPY Makefile mix.exs mix.lock ./

# Get Elixir dependencies, and compile them
RUN make deps
RUN make build

# You may wonder why I am splitting dependency compilation from the app one?
# Well, your dependencies changes less than your source code. If one copy
# the whole project each time instead, every change in your code will bust
# docker cache and continually redownload/build all your dependencies.
#
# By separating those two stages we can only focus on rebuilding our changes,
# and not our whole dependency chain each time.

# This copy the rest of our apps
COPY . .

RUN make build

# This step builds assets for the Phoenix app (if there is one)
# RUN mix assets.deploy

FROM builder AS releaser

RUN mkdir -p /opt/built \
    && make release \
    && cp -r _build/${MIX_ENV}/rel/${APP_NAME}/releases/${APP_VSN}/* /opt/built/

# From this line onwards, we're in a new image, which will be the image used in production
FROM alpine:${ALPINE_VERSION} as production

# The name of your application/release (required)
ARG APP_NAME

RUN apk update &&      \
    apk add --no-cache \
    bash             \
    curl             \
    libssl1.1        \
    dumb-init        \
    gcc              \
    g++

ENV REPLACE_OS_VARS=true
ENV APP_NAME=${APP_NAME}

WORKDIR /opt/app

COPY --from=releaser /opt/built .

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["bash", "-c", "/opt/app/bin/$APP_NAME start"]
