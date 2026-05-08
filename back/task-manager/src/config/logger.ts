import pino from "pino";
import type { Request } from "express";

const logLevel = process.env.LOG_LEVEL ?? "info";
const prettyLogs = process.env.LOG_PRETTY === "true";

const transport = prettyLogs
  ? {
      target: "pino-pretty",
      options: {
        colorize: true,
        translateTime: "SYS:standard",
        ignore: "pid,hostname",
      },
    }
  : undefined;

// ✅ FIX: Pass transport inside the options
export const logger = pino({
  level: logLevel,
  base: { service: "task-manager" },
  redact: ["req.headers.authorization", "req.headers.cookie"],
  ...(transport && { transport }), // ← Spread condicional
});

export const getRequestLogger = (req: Request) =>
  logger.child({
    requestId: req.id,
    method: req.method,
    path: req.originalUrl,
    userId: req.user?.sub,
  });
