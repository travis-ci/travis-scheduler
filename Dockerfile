FROM ruby:2.6.5-slim

LABEL maintainer Travis CI GmbH <support+travis-scheduler-docker-images@travis-ci.com>

# packages required for bundle install
RUN ( \
   apt-get update ; \
   # update to deb 10.8
   apt-get upgrade -y ; \
   apt-get install -y --no-install-recommends git make gcc g++ libpq-dev libjemalloc-dev \
   && rm -rf /var/lib/apt/lists/* \
)

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN bundle config set deployment 'true'

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile      /app
COPY Gemfile.lock /app

RUN gem install bundler -v '2.1.4'

ARG bundle_gems__contribsys__com
RUN bundle config https://gems.contribsys.com/ $bundle_gems__contribsys__com \
      &&  bundle config set without 'development test'\
      && bundle install\
      && bundle config --delete https://gems.contribsys.com/
RUN gem install --user-install executable-hooks
COPY . /app

RUN bundle config unset frozen
RUN cd /usr/local/bundle/gems/travis-lock-0.1.1 && sed "s/'activerecord'/'activerecord','~>4.2'/g" Gemfile -i && bundle update activerecord && bundle update redlock
RUN bundle config set frozen true

CMD bundle exec bin/sidekiq-pgbouncer ${SIDEKIQ_CONCURRENCY:-5} ${SIDEKIQ_QUEUE:-scheduler}
