FROM chatwoot:development

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV BUNDLE_PATH=/gems
ENV GEM_HOME=/gems
ENV GEM_PATH=/gems

# Install native extension dependencies
RUN apk add --no-cache \
  yaml-dev \
  postgresql-dev \
  openssl-dev \
  rust \
  cargo \
  ruby-dev \
  clang-dev \
  build-base \
  linux-headers \
  git

# Configure git to avoid hardlink issues
RUN git config --global core.hardlinks false

RUN chmod +x docker/entrypoints/vite.sh

EXPOSE 3036
CMD ["bin/vite", "dev"]
