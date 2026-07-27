FROM magento/magento-cloud-docker-php:8.5-fpm-1.4.9

# Install Node.js 20.x
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash - && \
  apt-get install -y nodejs && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*


# Install Yarn
RUN npm install -g yarn

CMD ["php-fpm", "-R"]
