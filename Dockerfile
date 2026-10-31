FROM ruby:3.4-bookworm

RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends build-essential libpq-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install || true

COPY . .

EXPOSE 3000

CMD ["bash", "-lc", "bundle install && rm -f tmp/pids/server.pid && bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0 -p 3000"]