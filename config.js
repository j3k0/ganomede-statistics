var pkg = require("./package.json");

module.exports = {
  port: +process.env.PORT || 8000,
  routePrefix: process.env.ROUTE_PREFIX || pkg.api,

  coordinator: {
    protocol: process.env.COORDINATOR_PORT_8080_TCP_PROTOCOL || 'http',
    host: process.env.COORDINATOR_PORT_8080_TCP_ADDR || 'localhost',
    port: +process.env.COORDINATOR_PORT_8080_TCP_PORT || 8080
  },

  redis: {
    host: process.env.REDIS_STATISTICS_PORT_6379_TCP_ADDR || 'localhost',
    port: +process.env.REDIS_STATISTICS_PORT_6379_TCP_PORT || 6379,
    db: +process.env.REDIS_STATISTICS_PORT_6379_DB || null,
    prefix: pkg.api
  }
};
