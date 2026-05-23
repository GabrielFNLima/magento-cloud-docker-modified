FROM magento/magento-cloud-docker-php:8.3-fpm-1.4.8

# Install Node.js LTS
RUN curl -sL https://deb.nodesource.com/setup_lts.x | bash - && \
  apt-get install -y nodejs && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*


# Install Yarn
RUN npm install -g yarn

CMD ["php-fpm", "-R"]