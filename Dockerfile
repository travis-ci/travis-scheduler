# Defining platform type
ARG PLATFORM_TYPE=hosted

# Building the hosted base image
FROM ruby:2.6.5-slim as builder-hosted

RUN ( \
   apt-get update ; \
   apt-get install -y --no-install-recommends gettext-base git make gcc g++ libpq-dev libjemalloc-dev openssh-server \
   && rm -rf /var/lib/apt/lists/* \
)
RUN mkdir -p /app
COPY . /app

# Building the enterprise base image
FROM builder-hosted as builder-enterprise

ARG RUBYENCODER_PROJECT_ID
ARG RUBYENCODER_PROJECT_KEY
ARG SSH_KEY
RUN ( \
   if test $RUBYENCODER_PROJECT_ID; then \
     chmod +x /app/bin/te-encode && \
     ./app/bin/te-encode && \
     rm -rf /root/.ssh/id_rsa; \
   fi; \
)

FROM builder-${PLATFORM_TYPE}
LABEL maintainer Travis CI GmbH <support+travis-app-docker-images@travis-ci.com>

RUN ( \
   apt-get update ; \
   apt-get install -y --no-install-recommends gettext-base git make g++ libpq-dev \
   && rm -rf /var/lib/apt/lists/* \
)
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
RUN gem i bundler --no-document -v=2.1.4

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN bundle config set deployment 'true'

WORKDIR /app

COPY Gemfile      /app
COPY Gemfile.lock /app

ARG bundle_gems__contribsys__com
RUN bundle config https://gems.contribsys.com/ $bundle_gems__contribsys__com \
      && bundle install \
      && bundle config --delete https://gems.contribsys.com/

CMD bundle exec bin/sidekiq-pgbouncer ${SIDEKIQ_CONCURRENCY:-5} ${SIDEKIQ_QUEUE:-scheduler}
