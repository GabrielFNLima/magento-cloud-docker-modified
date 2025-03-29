# Magento Cloud Docker Images Modified

This repository contains modified Docker images for Magento Cloud development environments. The images extend the official Magento Cloud Docker images with additional functionality, such as pre-installed Node.js and other tools to enhance the development workflow.

## Based on Official Magento Cloud Docker

These images are based on the official [Magento Cloud Docker repository](https://github.com/magento/magento-cloud-docker). We extend the official images to add additional functionality while maintaining compatibility with the Magento Cloud infrastructure.

## Available Images

### PHP-FPM with Node.js

Our custom images extend the official Magento Cloud Docker PHP images with the following additions:

- PHP-FPM with Node.js pre-installed
- Multiple PHP versions (7.4, 8.0, 8.1, 8.2, 8.3)
- Magento Cloud Docker version (1.4.0, 1.3.7)
- Node.js versions (18lts)

## How to Use These Images

To use these modified images in your Magento Cloud Docker development environment, you need to update your `docker-compose.yml` file to reference our custom images instead of the official Magento Cloud Docker images.

### Steps to Update Your Docker Configuration

1. Open your project's `docker-compose.yml` file
2. Locate the `fpm` and `fpm_xdebug` service definitions
3. Replace the image references with our custom images

#### Example Change

**From:**

```yaml
fpm:
  image: magento/magento-cloud-docker-php:8.2-fpm-1.4.0

fpm_xdebug:
  image: magento/magento-cloud-docker-php:8.2-fpm-1.4.0
```

**To:**

```yaml
fpm:
  image: devgfnl/magento-cloud-docker-php-node:8.2-fpm-node18-1.4.0

fpm_xdebug:
  image: devgfnl/magento-cloud-docker-php-node:8.2-fpm-node18-1.4.0
```

#### Rebuild and Restart Your Containers

```bash
docker compose down

```

```bash
docker compose up -d
```

### Available Combinations

#### PHP Versions

| PHP Version | Node.js Version | Image Tag                                                    |
| ----------- | --------------- | ------------------------------------------------------------ |
| 8.3         | 18              | `devgfnl/magento-cloud-docker-php-node:8.3-fpm-node18-1.4.0` |
| 8.2         | 18              | `devgfnl/magento-cloud-docker-php-node:8.2-fpm-node18-1.4.0` |
| 8.1         | 18              | `devgfnl/magento-cloud-docker-php-node:8.1-fpm-node18-1.4.0` |
| 8.0         | 18              | `devgfnl/magento-cloud-docker-php-node:8.0-fpm-node18-1.4.0` |
| 7.4         | 18              | `devgfnl/magento-cloud-docker-php-node:7.4-fpm-node18-1.4.0` |
| 8.3         | 18              | `devgfnl/magento-cloud-docker-php-node:8.3-fpm-node18-1.3.7` |
| 8.2         | 18              | `devgfnl/magento-cloud-docker-php-node:8.2-fpm-node18-1.3.7` |
| 8.1         | 18              | `devgfnl/magento-cloud-docker-php-node:8.1-fpm-node18-1.3.7` |
| 8.0         | 18              | `devgfnl/magento-cloud-docker-php-node:8.0-fpm-node18-1.3.7` |
| 7.4         | 18              | `devgfnl/magento-cloud-docker-php-node:7.4-fpm-node18-1.3.7` |

## Contributing

If you need additional PHP or Node.js versions, please open an issue or submit a pull request.

## License

This project is licensed under the same terms as the original Magento Cloud Docker images.
