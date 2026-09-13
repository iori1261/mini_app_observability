const { randomUUID } = require("crypto");
const express = require("express");
const log = require("./log");

const app = express();
const port = Number(process.env.PORT || 4000);

app.use(express.json());
app.use((req, res, next) => {
  const requestId = req.get("x-request-id") || randomUUID();
  req.requestId = requestId;
  res.set("x-request-id", requestId);
  log.addTransactionAttributes({ "request.id": requestId });
  next();
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "payments" });
});

app.post("/charge", (req, res) => {
  const fail = Boolean(req.body?.fail);
  const amount = Number(req.body?.amount || 0);

  log.addTransactionAttributes({
    "payment.amount": amount,
    "payment.fail": fail,
  });

  if (fail) {
    const error = new Error("Payment gateway unavailable");
    log.noticeError(error, { requestId: req.requestId });
    log.error("charge_failed", { requestId: req.requestId, amount });
    return res.status(503).json({
      error: "payment_gateway_unavailable",
      message: error.message,
      requestId: req.requestId,
    });
  }

  const charge = {
    chargeId: randomUUID(),
    status: "captured",
    amount,
    requestId: req.requestId,
  };
  log.info("charge_captured", { requestId: req.requestId, ...charge });
  res.json(charge);
});

app.listen(port, "0.0.0.0", () => {
  log.info("payments_started", { port });
});
