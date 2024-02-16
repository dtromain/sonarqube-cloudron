# Sonarqube Cloudron App

This repository contains the Sonarqube app package source for [Sonarqube](https://www.sonarsource.com/products/sonarqube/).

## Installation

Using the [Cloudron command line tooling](https://cloudron.io/references/cli.html)

```
cloudron install --appstore-id com.sonarqube.cloudronapp
```

## Building

The app package can be built using the [Sonarqube command line tooling](https://cloudron.io/references/cli.html).

```
cd sonarqube-app
cloudron build
cloudron install
```

## Testing

The e2e tests are located in the `test/` folder and require [nodejs](http://nodejs.org/). They are creating a fresh build, install the app on your Cloudron, verify auth, upload a file, backup, restore and verify the file still being present.

```
cd sonarqube-app/test

npm install
USERNAME=<cloudron username> PASSWORD=<cloudron password> mocha test.js
```