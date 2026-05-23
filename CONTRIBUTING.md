# Contributing

## Adding new image variants

New Dockerfiles follow the directory convention:

```
images/php-nodejs/{php_version}-fpm/{cloud_version}/{node_variant}/Dockerfile
```

To add a new combination, copy an existing Dockerfile from the same PHP line and adjust the `FROM` tag and nodesource setup script:

| Variant   | Setup script      |
| --------- | ----------------- |
| `node20`  | `setup_20.x`      |
| `node24`  | `setup_24.x`      |
| `nodelts` | `setup_lts.x`     |

Any Node.js version available on [nodesource](https://github.com/nodesource/distributions) can be used — just replace the setup script accordingly. For example, to add Node.js 16 for PHP 8.5:

```bash
mkdir -p images/php-nodejs/8.5-fpm/1.4.8/node16
```

```dockerfile
FROM magento/magento-cloud-docker-php:8.5-fpm-1.4.8

RUN curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
  apt-get install -y nodejs && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN npm install -g yarn

CMD ["php-fpm", "-R"]
```

## Validating before opening a PR

Build and smoke-test only what changed:

```bash
./scripts/build-and-smoke.sh --changed-only --diff-base origin/main --diff-head HEAD
```

Or test a specific combination:

```bash
./scripts/build-and-smoke.sh --php 8.5 --node nodelts --cloud-version 1.4.8
```

The smoke test verifies that `php -v`, `node -v`, and `yarn -v` all run successfully inside the built container.

## Pull request checklist

- [ ] Smoke test passes locally
- [ ] README table updated if new PHP versions or cloud versions were added
- [ ] One PR per feature/version bump (do not mix unrelated changes)

## CI

Every PR against `main` triggers the `build-and-smoke` workflow, which automatically builds and smoke-tests only the Dockerfiles changed in the PR diff. The PR must pass CI before merging.
