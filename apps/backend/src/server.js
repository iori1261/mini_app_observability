if (process.env.NEW_RELIC_LICENSE_KEY) {
  require("newrelic");
}

const serviceName = process.env.SERVICE_NAME || "api";

if (serviceName === "payments") {
  require("./payments");
} else {
  require("./api");
}
