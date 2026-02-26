import jwt from "jsonwebtoken";

function requireAuth(req, res, next) {
  const auth = req.headers.authorization || "";
  const hasAuthHeader = auth.startsWith("Bearer ");
  const token = hasAuthHeader ? auth.slice(7) : "";
  const tokenParts = token ? token.split(".").length : 0;
  const jwtSecret = String(process.env.JWT_SECRET || "");
  const jwtSecretLen = jwtSecret.length;

  console.log(
    `[AUTHDBG] ${req.method} ${req.path} hasAuthHeader=${hasAuthHeader} tokenParts=${tokenParts} jwtSecretLen=${jwtSecretLen}`
  );

  if (!hasAuthHeader || !token || tokenParts !== 3) {
    return res.status(401).json({ error: "unauthorized" });
  }

  try {
    const decoded = jwt.verify(token, jwtSecret);
    req.user = decoded;
    return next();
  } catch (err) {
    console.log(`[AUTHDBG] ${req.method} ${req.path} verifyError=${err.message}`);
    return res.status(401).json({ error: "unauthorized" });
  }
}

export { requireAuth };
