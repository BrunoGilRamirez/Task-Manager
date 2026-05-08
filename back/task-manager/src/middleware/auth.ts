import type { Request, Response, NextFunction } from "express";
import { supabase } from "../config/supabaseClient.js";
import { getRequestLogger } from "../config/logger.js";

export async function authenticateUser(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const log = getRequestLogger(req);
    const authHeader = req.headers.authorization;

    if (!authHeader?.startsWith("Bearer ")) {
      log.warn({ hasAuthHeader: Boolean(authHeader) }, "auth.missing_token");
      res.status(401).json({ error: "No token provided" });
      return;
    }

    const token = authHeader.substring(7);

    // ✅ Verificar el JWT usando el cliente de Supabase
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser(token);

    if (error || !user) {
      log.warn(
        { authError: error?.message, hasUser: Boolean(user) },
        "auth.invalid_token",
      );
      res.status(401).json({ error: "Invalid or expired token" });
      return;
    }

    // Add user to request (SAME STRUCTURE)
    req.user = {
      sub: user.id,
      email: user.email,
      accessToken: token,
    };

    log.debug({ userId: user.id }, "auth.ok");
    next();
  } catch (error) {
    const log = getRequestLogger(req);
    log.error({ err: error }, "auth.error");
    res.status(401).json({ error: "Invalid or expired token" });
  }
}
