const { randomUUID } = require("crypto");
const express = require("express");
const log = require("./log");

const app = express();
const port = Number(process.env.PORT || 8080);
const paymentsUrl = process.env.PAYMENTS_URL || "http://payments:4000";
const orders = new Map();

app.use(express.json());
app.use((req, res, next) => {
  const requestId = req.get("x-request-id") || randomUUID();
  req.requestId = requestId;
  req.clientAction = req.get("x-client-action") || "unknown";
  req.clientPlatform = req.get("x-client-platform") || "unknown";
  res.set("x-request-id", requestId);
  res.set("access-control-allow-origin", "*");
  res.set("access-control-expose-headers", "x-request-id");

  log.addTransactionAttributes({
    "request.id": requestId,
    "client.action": req.clientAction,
    "client.platform": req.clientPlatform,
  });

  const started = Date.now();
  res.on("finish", () => {
    log.info("http_request", {
      requestId,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs: Date.now() - started,
      clientAction: req.clientAction,
      clientPlatform: req.clientPlatform,
    });
  });

  next();
});

app.options("*", (_req, res) => {
  res.set("access-control-allow-origin", "*");
  res.set("access-control-allow-headers", "content-type, x-request-id, x-client-action, x-client-platform");
  res.set("access-control-allow-methods", "GET,POST,OPTIONS");
  res.status(204).end();
});

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    service: "api",
    time: new Date().toISOString(),
  });
});

app.post("/orders", async (req, res) => {
  await createOrder(req, res, { delayMs: 0, failPayment: false });
});

app.post("/orders/slow", async (req, res) => {
  await createOrder(req, res, { delayMs: 2000, failPayment: false });
});

app.get("/orders/:id", (req, res) => {
  const order = orders.get(req.params.id);
  if (!order) {
    return res.status(404).json({
      error: "order_not_found",
      requestId: req.requestId,
    });
  }

  res.json(order);
});

app.post("/chaos/error", (req, res) => {
  const error = new Error("Intentional API failure for New Relic verification");
  log.noticeError(error, { requestId: req.requestId, scenario: "server_error" });
  log.error("chaos_server_error", { requestId: req.requestId });
  res.status(500).json({
    error: "intentional_server_error",
    message: error.message,
    requestId: req.requestId,
  });
});

app.post("/chaos/dependency", async (req, res) => {
  await createOrder(req, res, { delayMs: 0, failPayment: true });
});

app.use((error, req, res, _next) => {
  log.noticeError(error, { requestId: req.requestId });
  log.error("unhandled_error", {
    requestId: req.requestId,
    message: error.message,
  });
  res.status(500).json({
    error: "unhandled_error",
    message: error.message,
    requestId: req.requestId,
  });
});

async function createOrder(req, res, { delayMs, failPayment }) {
  const sku = String(req.body?.sku || "demo-item");
  const quantity = Number(req.body?.quantity || 1);
  const amount = quantity * 1200;

  log.addTransactionAttributes({
    "order.sku": sku,
    "order.quantity": quantity,
    "order.amount": amount,
    "order.slow": delayMs > 0,
    "order.failPayment": failPayment,
  });

  if (delayMs > 0) {
    log.info("slow_order_delay", { requestId: req.requestId, delayMs });
    await sleep(delayMs);
  }

  try {
    const charge = await chargePayment({
      amount,
      fail: failPayment,
      requestId: req.requestId,
    });

    const order = {
      id: randomUUID(),
      sku,
      quantity,
      amount,
      status: "paid",
      chargeId: charge.chargeId,
      requestId: req.requestId,
      createdAt: new Date().toISOString(),
    };
    orders.set(order.id, order);

    log.info("order_created", {
      requestId: req.requestId,
      orderId: order.id,
      sku,
      quantity,
      amount,
    });

    res.status(201).json(order);
  } catch (error) {
    log.noticeError(error, {
      requestId: req.requestId,
      scenario: "dependency_failure",
    });
    log.error("order_payment_failed", {
      requestId: req.requestId,
      message: error.message,
    });
    res.status(502).json({
      error: "payment_failed",
      message: error.message,
      requestId: req.requestId,
    });
  }
}

async function chargePayment({ amount, fail, requestId }) {
  const response = await fetch(`${paymentsUrl}/charge`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-request-id": requestId,
    },
    body: JSON.stringify({ amount, fail }),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.message || payload.error || "payments unavailable");
  }

  return payload;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

app.listen(port, "0.0.0.0", () => {
  log.info("api_started", { port, paymentsUrl });
});
