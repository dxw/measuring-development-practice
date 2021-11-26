FROM ruby:2-alpine

RUN apk add git

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY scripts /scripts

ENTRYPOINT ["ruby", "/scripts/pull_release_stats.rb", "--repository", "dxw/playbook"]