FROM debian:12

# Set environment variables
ENV RMA_INSTALLATION_PATH=/var/www/html/sql-ledger

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
  # RMA_FORCE_HTTPS=yes \
  PERL5LIB=${RMA_INSTALLATION_PATH} \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en \
  LC_ALL=en_US.UTF-8

ENV DEBIAN_PACKAGES="libmojolicious-perl \
  libdbi-perl \
  libdbd-pg-perl \
  libdbix-simple-perl \
  libfile-pushd-perl \
  libtext-csv-xs-perl \
  libxml-libxml-perl \
  libjson-xs-perl \
  libfile-slurper-perl \
  libdbd-pg-perl \
  libtext-markdown-perl \
  libdbix-simple-perl \
  libcgi-formbuilder-perl \
  libcgi-formbuilder-perl \
  libfile-type-perl \
  libmojo-pg-perl \
  libopenoffice-oodoc-perl \
  libgd-graph-perl \
  libyaml-tiny-perl \
  zip \
  texlive \
  pdftk"

ENV PERL_MODULES="Mojolicious::Plugin::I18N \
  DBIx::XHTML_Table"

# Install packages
RUN apt-get update && \
  apt-get install -y \
  man \
  unzip \
  bash-completion \
  python3-psycopg2 \
  cpanminus \
  make \
  apache2 \
  postgresql-client \
  git \
  jq \
  locales \
  build-essential \
  libpq-dev \
  texlive-lang-german \
  texlive-lang-english \
  $DEBIAN_PACKAGES \
  && rm -rf /var/lib/apt/lists/*

# Generate locales
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
  sed -i '/de_CH/s/^# //g' /etc/locale.gen && \
  locale-gen


# Install Perl dependencies
RUN cpanm --notest \
  $PERL_MODULES \
  HTML::FromText \
  && rm -rf /root/.cpanm

# Enable Apache modules
RUN a2enmod \
  ssl \
  cgid \
  rewrite \
  headers \
  proxy \
  proxy_http \
  && \
  a2ensite default-ssl

# Remove default site
RUN a2dissite 000-default && \
  rm /var/www/html/index.html

# Configure Apache for debugging
RUN echo "LogLevel debug" >> /etc/apache2/apache2.conf && \
  echo "ErrorLog /dev/stderr" >> /etc/apache2/apache2.conf && \
  echo "CustomLog /dev/stdout combined" >> /etc/apache2/apache2.conf

# Set working directory
WORKDIR ${RMA_INSTALLATION_PATH}

# Copy source and package lists with proper permissions
COPY --chown=www-data:www-data . ${RMA_INSTALLATION_PATH}

# Copy application setup files
COPY ./infra/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
