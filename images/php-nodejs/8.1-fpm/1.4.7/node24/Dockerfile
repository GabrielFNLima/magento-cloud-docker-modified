FROM magento/magento-cloud-docker-php:8.1-fpm-1.4.7

# Install Node.js 24.x
RUN curl -sL https://deb.nodesource.com/setup_24.x | bash - && \
  apt-get install -y nodejs && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*


# Install Yarn
RUN npm install -g yarn

CMD ["php-fpm", "-R"]
