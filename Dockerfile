FROM ruby:3.2.2-slim

LABEL maintainer Travis CI GmbH <support+travis-scheduler-docker-images@travis-ci.com>

RUN ( \
   bundle config set no-cache 'true'; \
   bundle config --global frozen 1; \
   bundle config set deployment 'true'; \
   mkdir -p /app; \
)
WORKDIR /app
COPY Gemfile*      /app/
ARG bundle_gems__contribsys__com
RUN ( \
   apt-get update ; \
   apt-get upgrade -y ; \
   apt-get install -y --no-install-recommends git make gcc g++ libpq-dev libjemalloc-dev libcurl4 \
   && rm -rf /var/lib/apt/lists/*; \
   gem update --system; \
   gem install bundler -v '2.3.24'; \
   bundle config https://gems.contribsys.com/ $bundle_gems__contribsys__com; \
   bundle config set without 'development test'; \
   bundle install; \
   bundle config --delete https://gems.contribsys.com; \
   apt-get remove -y gcc g++ make git perl && apt-get -y autoremove; \
   bundle clean && rm -rf /app/vendor/bundle/ruby/2.7.0/cache/*; \
   for i in `find /app/vendor/ -name \*.o -o -name \*.c -o -name \*.h`; do rm -f $i; done; \
)

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN bundle config set deployment 'true'

RUN mkdir -p /app
WORKDIR /app

COPY Gemfile      /app
COPY Gemfile.lock /app

RUN gem install bundler -v '2.4.14'

ARG bundle_gems__contribsys__com
RUN bundle config https://gems.contribsys.com/ $bundle_gems__contribsys__com \
      && bundle install \
      && bundle config --delete https://gems.contribsys.com/
RUN gem install --user-install executable-hooks

COPY . /app

CMD ["bundle", "exec", "bin/sidekiq-pgbouncer", "${SIDEKIQ_CONCURRENCY:-5}", "${SIDEKIQ_QUEUE:-scheduler}"]
