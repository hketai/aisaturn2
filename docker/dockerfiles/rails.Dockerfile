FROM chatwoot:development

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV BUNDLE_PATH=/gems
ENV GEM_HOME=/gems
ENV GEM_PATH=/gems

# Install native extension dependencies for gem compilation
# These are required for: grpc, commonmarker, pg, psych, etc.
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

# Configure git to avoid hardlink issues on overlay filesystem
RUN git config --global core.hardlinks false

# Make entrypoint executable
RUN chmod +x docker/entrypoints/rails.sh

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]