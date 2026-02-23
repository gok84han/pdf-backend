import { requireAuth } from "./middleware/auth.js";

import express from "express";
import multer from "multer";
import cors from "cors";
import dotenv from "dotenv";
import * as pdfjsLib from "pdfjs-dist/legacy/build/pdf.mjs";
import { OAuth2Client } from "google-auth-library";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import jwt from "jsonwebtoken";

dotenv.config();
const JWT_SECRET = String(process.env.JWT_SECRET || "").trim();
if (!JWT_SECRET) {
  console.error("[FATAL] JWT_SECRET missing");
}

const PORT = process.env.PORT || 8787;
const LOG_LEVEL = process.env.LOG_LEVEL || "info";
const isDebug = LOG_LEVEL === "debug";
const ALLOW_DEBUG_PLAN_ACTIVATION =
  String(process.env.ALLOW_DEBUG_PLAN_ACTIVATION || "")
    .trim()
    .toLowerCase() === "true";
const ALLOW_DEV_TOKEN =
  String(process.env.ALLOW_DEV_TOKEN || "")
    .trim()
    .toLowerCase() === "true";
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const GOOGLE_CLIENT_IDS = String(process.env.GOOGLE_CLIENT_IDS || "")
  .split(",")
  .map((v) => v.trim())
  .filter(Boolean);
const AUTH_AUDIENCES = Array.from(
  new Set([...GOOGLE_CLIENT_IDS, ...(GOOGLE_CLIENT_ID ? [GOOGLE_CLIENT_ID] : [])])
);
const GOOGLE_ALLOWED_CLIENT_IDS = AUTH_AUDIENCES;
const EXPECTED_AUDIENCE = GOOGLE_ALLOWED_CLIENT_IDS;
const googleOAuthClient = new OAuth2Client();

const app = express();
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    console.log(`[REQ] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${Date.now() - start}ms) ct=${req.headers["content-type"] || ""}`);
  });
  next();
});

// --- Upload limits (MVP) ---
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB
  fileFilter: (req, file, cb) => {
    const ok =
      file.mimetype === "application/pdf" ||
      file.originalname.toLowerCase().endsWith(".pdf");
    cb(ok ? null : new Error("ONLY_PDF"), ok);
  },
});

// --- Core prompts (Exact Prompt) ---
const SYSTEM_PROMPT = `
You are an expert business analyst and executive assistant.

Your task is to analyze a document provided as plain text extracted from a PDF.
You must NOT provide legal, medical, or financial advice.
You must NOT assume facts that are not explicitly stated in the document.
You must NOT hallucinate missing information.

Your goal is NOT to summarize the document,
but to extract decision-oriented insights that help a busy professional
understand what matters and what actions are required.

Be concise, structured, and practical.
Avoid filler language, generic advice, and vague statements.
`.trim();

const DOCUMENT_TYPE_DETECTION_SYSTEM_PROMPT = `
You are a strict JSON-only document type detector.
Return valid JSON only.
`.trim();

const DOCUMENT_TYPE_PROMPT_PATH = path.resolve(
  process.cwd(),
  "backend/ai/prompts/document_type_detection.prompt.txt"
);
const DOCUMENT_TYPE_DETECTION_PROMPT = (() => {
  try {
    return fs.readFileSync(DOCUMENT_TYPE_PROMPT_PATH, "utf8").trim();
  } catch {
    return `
Detect the document type from the text below.
Return JSON only with:
{
  "detected_language": "...",
  "document_type": "contract | non_contract | unknown",
  "confidence": "high | medium | low"
}
<<<DOCUMENT_TEXT
{{document_text}}
DOCUMENT_TEXT>>>
`.trim();
  }
})();

const ALLOWED_DOCUMENT_TYPES = new Set(["contract", "non_contract", "unknown"]);
const RISK_LABEL_TYPES = Object.freeze({
  unilateral_obligation: "Tek tarafli yukumluluk",
  penalty_clause: "Ceza sarti / cayma bedeli",
  auto_renewal: "Otomatik yenileme / uzama",
  jurisdiction_arbitration: "Yetkili mahkeme / tahkim",
  data_processing: "KVKK / veri isleme / paylasim",
});
const ALLOWED_RISK_LABEL_TYPES = new Set(Object.keys(RISK_LABEL_TYPES));
const ALLOWED_RISK_CONFIDENCE = new Set(["low", "medium", "high"]);
const DISCLAIMER_SHORT =
  "Bu icerik hukuki danismanlik degildir; yalnizca karar destek amacli otomatik etiketlemedir.";
const DISCLAIMER_LONG =
  "Bu cikti hukuki gorus veya danismanlik niteliginde degildir. Sistem, metindeki ifadelere dayali olasi risk etiketlerini gosterebilir; bir maddenin hukuka aykiri oldugunu iddia etmez ve imzalama karari onermez.";
const RISK_LABELING_SYSTEM_PROMPT = `
You are a contract risk label extractor.
This is NOT legal advice.
Do not say a clause is illegal.
Do not tell user to sign or not sign.
Only identify phrases that may create risk in similar contracts.
Return JSON only.
`.trim();

function buildUserPrompt(pdfText) {
  return `
Analyze the following document text and produce the output strictly in the structure below.

DOCUMENT TEXT:
<<<
${pdfText}
>>>

OUTPUT STRUCTURE:

1. EXECUTIVE SNAPSHOT
- In 3–5 bullet points, explain:
  • What this document is about
  • Who it is intended for
  • The main objective or decision context

2. KEY POINTS
- List the most important facts, decisions, or statements.
- Use short, clear bullet points.
- Exclude background, marketing language, or repeated explanations.

3. RISKS & UNCERTAINTIES
- Identify:
  • Ambiguities
  • Missing information
  • Potential risks or red flags
- If none are explicitly present, state: "No explicit risks identified."

4. ACTION ITEMS
- Extract concrete actions implied or required by the document.
- For each action, use this format:
  • Action:
  • Who:
  • When:
- If information is missing, write "Not specified".

RULES:
- Do NOT add advice beyond the document.
- Do NOT invent deadlines, responsibilities, or conclusions.
- If the document is informational only, clearly state that no actions are required.
`.trim();
}

function normalizeDocumentType(value, { allowEmpty = false } = {}) {
  const t = String(value ?? "").trim().toLowerCase();
  if (ALLOWED_DOCUMENT_TYPES.has(t)) return t;
  return allowEmpty ? "" : "unknown";
}

function buildDocumentTypePrompt(documentText) {
  if (DOCUMENT_TYPE_DETECTION_PROMPT.includes("{{document_text}}")) {
    return DOCUMENT_TYPE_DETECTION_PROMPT.replace("{{document_text}}", documentText);
  }
  return `${DOCUMENT_TYPE_DETECTION_PROMPT}\n\n<<<DOCUMENT_TEXT\n${documentText}\nDOCUMENT_TEXT>>>`;
}

function buildRiskLabelingPrompt(documentText) {
  return `
Task: Extract pattern-based risk labels from the contract text.

Allowed types:
- unilateral_obligation
- penalty_clause
- auto_renewal
- jurisdiction_arbitration
- data_processing

Safety rules:
- This is not legal advice.
- Do not say any clause is illegal.
- Do not say "sign" or "do not sign".
- Use soft wording like: "benzer sozlesmelerde risk olusturabilen ifade olabilir".
- excerpt must be a direct short quote from contract text, max 200 characters.
- confidence must be one of: low | medium | high.

Return JSON only in this schema:
{
  "riskLabels": [
    {
      "type": "unilateral_obligation | penalty_clause | auto_renewal | jurisdiction_arbitration | data_processing",
      "title": "short title",
      "excerpt": "short quote max 200 chars",
      "confidence": "low | medium | high",
      "note": "one sentence, non-legal, soft language"
    }
  ]
}

If no pattern matched, return:
{"riskLabels":[]}

<<<CONTRACT_TEXT
${documentText}
CONTRACT_TEXT>>>
`.trim();
}

function parseJsonSafe(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function detectLanguageFallbackFromSummary(summarySections) {
  const text = Array.isArray(summarySections)
    ? summarySections
        .map((section) => `${String(section?.title ?? "")} ${String(section?.content ?? "")}`)
        .join(" ")
    : "";
  return /[çğıöşüÇĞİÖŞÜ]/.test(text) ? "tr" : "en";
}

// --- Helpers ---
function clampText(text, maxChars) {
  if (!text) return "";
  const t = String(text).replace(/\u0000/g, "").trim();
  return t.length > maxChars ? t.slice(0, maxChars) : t;
}

function normalizeRiskLabel(entry) {
  if (!entry || typeof entry !== "object") return null;
  const type = String(entry.type ?? "")
    .trim()
    .toLowerCase();
  if (!ALLOWED_RISK_LABEL_TYPES.has(type)) return null;
  const title = clampText(String(entry.title ?? RISK_LABEL_TYPES[type] ?? type), 80);
  const excerpt = clampText(String(entry.excerpt ?? ""), 200);
  if (!excerpt) return null;
  const confidenceRaw = String(entry.confidence ?? "")
    .trim()
    .toLowerCase();
  const confidence = ALLOWED_RISK_CONFIDENCE.has(confidenceRaw)
    ? confidenceRaw
    : "medium";
  const note =
    clampText(String(entry.note ?? ""), 200) ||
    "Benzer sozlesmelerde risk olusturabilen ifade olabilir.";
  return { type, title, excerpt, confidence, note };
}

function normalizeRiskLabels(raw) {
  const list = Array.isArray(raw) ? raw : [];
  const seen = new Set();
  const out = [];
  for (const item of list) {
    const normalized = normalizeRiskLabel(item);
    if (!normalized) continue;
    const dedupeKey = `${normalized.type}:${normalized.excerpt}`;
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    out.push(normalized);
    if (out.length >= 20) break;
  }
  return out;
}

const MONTHLY_FREE_QUOTA = 15;
const monthlyQuotaUsage = new Map();
const userPlanBySub = new Map();
const analyzeResultCache = new Map();
const analyzeCacheOrder = [];
const ANALYZE_CACHE_MAX = 200;
const ANALYZE_CACHE_TRIM = 50;

function getUserPlan(userSub) {
  return userPlanBySub.get(userSub) === "pro" ? "pro" : "free";
}

function getCurrentMonthKey(date = new Date()) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

function getMonthlyQuotaKey(userId, date = new Date()) {
  return `${userId}:${getCurrentMonthKey(date)}`;
}

function getUserUsageCount(userId) {
  const key = getMonthlyQuotaKey(userId);
  const count = Number(monthlyQuotaUsage.get(key) ?? 0);
  if (!Number.isFinite(count) || count < 0) return 0;
  return Math.floor(count);
}

async function getCurrentMonthlyUsageCount(userId) {
  return getUserUsageCount(userId);
}

async function ensureMonthlyQuotaAvailable(userId) {
  const count = await getCurrentMonthlyUsageCount(userId);
  return count < MONTHLY_FREE_QUOTA;
}

async function incrementMonthlyUsage(userId) {
  const key = getMonthlyQuotaKey(userId);
  const nextCount = getUserUsageCount(userId) + 1;
  monthlyQuotaUsage.set(key, nextCount);
  return nextCount;
}

function setAnalyzeCache(cacheKey, resultJson) {
  if (!analyzeResultCache.has(cacheKey)) {
    analyzeCacheOrder.push(cacheKey);
  }
  analyzeResultCache.set(cacheKey, {
    resultJson,
    createdAt: new Date().toISOString(),
  });
  if (analyzeResultCache.size > ANALYZE_CACHE_MAX) {
    const evicted = analyzeCacheOrder.splice(0, ANALYZE_CACHE_TRIM);
    for (const key of evicted) {
      analyzeResultCache.delete(key);
    }
  }
}

async function requireAnalyzeQuota(req, res, next) {
  const userId = String(req.user?.sub ?? "").trim();
  if (!userId) {
    return res.status(401).json({ error: "UNAUTHORIZED" });
  }
  const usage = await getCurrentMonthlyUsageCount(userId);
  req.currentMonthlyUsage = usage;
  req.hasAnalyzeQuota = usage < MONTHLY_FREE_QUOTA;
  return next();
}

const ANALYSIS_TIMEOUT_MS = 60_000;
const RESERVATION_STATUS = {
  RESERVED: "RESERVED",
  FINALIZED: "FINALIZED",
  RELEASED: "RELEASED",
};
const JOB_STATUS = {
  PENDING: "PENDING",
  SUCCESS: "SUCCESS",
  FAILED: "FAILED",
};

let nextId = 1;
const quotaReservations = new Map();
const analysisJobs = new Map();
let quotaTxChain = Promise.resolve();

function createId(prefix) {
  const id = `${prefix}_${Date.now()}_${nextId}`;
  nextId += 1;
  return id;
}

function withQuotaTransaction(work) {
  const run = quotaTxChain.then(work);
  quotaTxChain = run.catch(() => {});
  return run;
}

async function reserveQuota({ userId, units = 1 }) {
  return withQuotaTransaction(async () => {
    const reservation = {
      id: createId("res"),
      userId,
      units,
      status: RESERVATION_STATUS.RESERVED,
      createdAt: new Date().toISOString(),
      finalizedAt: null,
      releasedAt: null,
    };
    quotaReservations.set(reservation.id, reservation);
    return { ...reservation };
  });
}

async function finalizeReservation(reservationId) {
  return withQuotaTransaction(async () => {
    const reservation = quotaReservations.get(reservationId);
    if (!reservation) throw new Error("RESERVATION_NOT_FOUND");
    if (reservation.status === RESERVATION_STATUS.RELEASED) {
      throw new Error("RESERVATION_ALREADY_RELEASED");
    }
    reservation.status = RESERVATION_STATUS.FINALIZED;
    reservation.finalizedAt = new Date().toISOString();
    return { ...reservation };
  });
}

async function releaseReservation(reservationId) {
  return withQuotaTransaction(async () => {
    const reservation = quotaReservations.get(reservationId);
    if (!reservation) return null;
    if (reservation.status !== RESERVATION_STATUS.RELEASED) {
      reservation.status = RESERVATION_STATUS.RELEASED;
      reservation.releasedAt = new Date().toISOString();
    }
    return { ...reservation };
  });
}

function createAnalysisJob(reservationId) {
  const job = {
    id: createId("job"),
    reservationId,
    status: JOB_STATUS.PENDING,
    error: null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  analysisJobs.set(job.id, job);
  return { ...job };
}

function setAnalysisJobStatus(jobId, status, error = null) {
  const job = analysisJobs.get(jobId);
  if (!job) return null;
  job.status = status;
  job.error = error;
  job.updatedAt = new Date().toISOString();
  return { ...job };
}

function getAnalysisJob(jobId) {
  const job = analysisJobs.get(jobId);
  return job ? { ...job } : null;
}

function getUpstreamStatusCode(message) {
  const match = /OPENAI_HTTP_(\d+):/.exec(message);
  if (!match) return null;
  return Number(match[1]);
}

async function withTimeout(promise, ms) {
  let timer = null;
  const timeoutPromise = new Promise((_, reject) => {
    timer = setTimeout(() => {
      const timeoutError = new Error("ANALYSIS_TIMEOUT");
      timeoutError.code = "ANALYSIS_TIMEOUT";
      reject(timeoutError);
    }, ms);
  });

  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

function extractResponsesApiText(response) {
  // Responses API returns text inside: response.output[].content[].text
  const out = Array.isArray(response?.output) ? response.output : [];
  const chunks = [];
  for (const item of out) {
    const content = Array.isArray(item?.content) ? item.content : [];
    for (const c of content) {
      if (c && typeof c.text === "string" && c.text.trim()) {
        chunks.push(c.text.trim());
      }
    }
  }
  return chunks.join("\n\n").trim();
}

async function callOpenAI({ system, user }) {
  if (process.env.MOCK_OPENAI === "1") {
    return JSON.stringify({
      summary: "MOCK SUMMARY",
      actions: [{ title: "MOCK ACTION 1" }, { title: "MOCK ACTION 2" }],
    });
  }

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("MISSING_OPENAI_API_KEY");

  const systemPrompt = system;
  const userPrompt = user;

  // Native fetch (Node 18+)
  const resp = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      input: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      // IMPORTANT: force plain text output (keeps your existing prompt structure)
      text: { format: { type: "text" } },
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`OPENAI_HTTP_${resp.status}: ${errText}`);
  }

  const response = await resp.json();
  console.log("OPENAI_RAW_JSON >>>", JSON.stringify(response, null, 2));

  const textOut = extractResponsesApiText(response);
  return textOut || "";
}

// --- Routes ---
app.get("/health", (req, res) => {
  res.json({ ok: true, service: "pdf-backend", port: PORT });
});

app.post("/auth/google", async (req, res) => {
  const idToken = String(req.body?.idToken ?? "").trim();
  if (!idToken) {
    console.error("[AUTH_GOOGLE] missing idToken");
    return res.status(401).json({ error: "UNAUTHORIZED", detail: "MISSING_ID_TOKEN" });
  }

  if (!JWT_SECRET) {
    return res.status(500).json({ error: "SERVER_ERROR", detail: "MISSING_JWT_SECRET" });
  }

  try {
    console.error("[AUTH_GOOGLE] expected audience:", EXPECTED_AUDIENCE);
    const ticket = await googleOAuthClient.verifyIdToken({
      idToken,
      audience: GOOGLE_ALLOWED_CLIENT_IDS,
    });
    const payload = ticket.getPayload();
    const sub = String(payload?.sub ?? "").trim();
    const email = String(payload?.email ?? "").trim();

    if (!sub) {
      console.error("[AUTH_GOOGLE] missing sub in verified token payload");
      return res.status(401).json({ error: "UNAUTHORIZED", detail: "MISSING_SUB" });
    }

    const token = jwt.sign({ sub, email }, JWT_SECRET);
    return res.json({ token });
  } catch (e) {
    const reason = String(e?.message || "").slice(0, 200);
    console.error("[AUTH_GOOGLE] verify failed:", reason);
    console.error("[AUTH_GOOGLE] expected audience:", EXPECTED_AUDIENCE);
    return res.status(401).json({
      error: "UNAUTHORIZED",
      detail: "GOOGLE_VERIFY_FAILED",
      reason,
    });
  }
});

app.post("/dev/token", (req, res) => {
  if (!ALLOW_DEV_TOKEN) {
    return res.status(404).json({ error: "NOT_FOUND" });
  }
  if (!JWT_SECRET) {
    return res.status(500).json({ error: "SERVER_ERROR", detail: "MISSING_JWT_SECRET" });
  }
  const token = jwt.sign({ sub: "dev-user-1" }, JWT_SECRET);
  return res.json({ token });
});

app.get("/me", requireAuth, async (req, res) => {
  if (isDebug) {
    console.log("[AUTH DEBUG] method=", req.method, "path=", req.path, "authorization=", req.headers.authorization);
  }
  const userId = String(req.user?.sub ?? "");
  const email = req.user?.email ?? null;
  const plan = getUserPlan(userId);
  const used = await getCurrentMonthlyUsageCount(userId);
  const remaining = Math.max(0, MONTHLY_FREE_QUOTA - used);

  return res.json({
    user_id: userId,
    email,
    plan,
    remainingQuota: remaining,
    proFeatures: {
      riskLabels: plan === "pro",
    },
    quota: {
      limit: MONTHLY_FREE_QUOTA,
      used,
      remaining,
    },
  });
});

app.post("/plan/activate", requireAuth, async (req, res) => {
  if (!ALLOW_DEBUG_PLAN_ACTIVATION) {
    return res.status(403).json({ error: "FORBIDDEN" });
  }
  const userId = String(req.user?.sub ?? "").trim();
  if (!userId) {
    return res.status(401).json({ error: "UNAUTHORIZED" });
  }
  const plan = String(req.body?.plan ?? "")
    .trim()
    .toLowerCase();
  if (plan !== "pro") {
    return res.status(400).json({ error: "BAD_REQUEST", detail: "PLAN_NOT_SUPPORTED" });
  }
  userPlanBySub.set(userId, "pro");
  return res.json({ ok: true, plan: "pro" });
});

app.post("/pdf/meta", requireAuth, upload.single("file"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "BAD_REQUEST", detail: "NO_FILE" });
  }

  const loadingTask = pdfjsLib.getDocument({
    data: new Uint8Array(req.file.buffer),
  });
  const doc = await loadingTask.promise;

  return res.status(200).json({
    filename: req.file.originalname,
    bytes: req.file.size,
    pages: doc.numPages,
    title: null,
    author: null,
  });
});

app.post("/analyze-pdf", requireAuth, requireAnalyzeQuota, upload.single("file"), async (req, res) => {
  if (isDebug) {
    console.log("[AUTH DEBUG] method=", req.method, "path=", req.path, "authorization=", req.headers.authorization);
  }
  console.log("[HIT] /analyze-pdf", new Date().toISOString());
  console.log("[FILE]", req.file?.originalname, req.file?.size);
  let reservation = null;
  let job = null;
  const userId = String(req.user?.sub ?? "").trim();
  const requestDocumentType = normalizeDocumentType(req.body?.document_type, {
    allowEmpty: true,
  });
  const isProPlan = getUserPlan(userId) === "pro";

  try {
    if (!req.file) {
      return res.status(400).json({ error: "BAD_REQUEST", detail: "NO_FILE" });
    }
    console.log("[UPLOAD] name=", req.file.originalname, "bytes=", req.file.size, "mime=", req.file.mimetype);

    const fileHash = crypto.createHash("sha256").update(req.file.buffer).digest("hex");
    const cacheKey = `${userId}:${getCurrentMonthKey()}:${isProPlan ? "pro" : "free"}:${fileHash}`;
    const cached = analyzeResultCache.get(cacheKey);
    if (cached?.resultJson) {
      if (isDebug) {
        console.log("[CACHE HIT]", cacheKey);
      }
      const cachedResponseJson = isProPlan
        ? cached.resultJson
        : { ...cached.resultJson, riskLabels: [] };
      return res.status(200).json(cachedResponseJson);
    }
    if (!req.hasAnalyzeQuota) {
      return res.status(403).json({ error: "QUOTA_EXCEEDED", limit: MONTHLY_FREE_QUOTA });
    }

    reservation = await reserveQuota({ userId, units: 1 });
    job = createAnalysisJob(reservation.id);

    const analysis = await withTimeout(
      (async () => {
        const loadingTask = pdfjsLib.getDocument({
          data: new Uint8Array(req.file.buffer),
        });
        const doc = await loadingTask.promise;
        let rawText = "";
        for (let i = 1; i <= doc.numPages; i++) {
          const page = await doc.getPage(i);
          const content = await page.getTextContent();
          rawText += content.items.map((it) => (it.str || "")).join(" ") + "\n";
        }

        const cleaned = clampText(rawText, 120_000);
        console.log("[PDF_TEXT_HEAD]", cleaned.slice(0, 300));
        if (!cleaned || cleaned.length < 200) {
          const badPdfError = new Error("PDF_TEXT_EMPTY_OR_SCANNED");
          badPdfError.code = "BAD_REQUEST";
          throw badPdfError;
        }

        const docTypePrompt = buildDocumentTypePrompt(cleaned);
        const docTypeOut = await callOpenAI({
          system: DOCUMENT_TYPE_DETECTION_SYSTEM_PROMPT,
          user: docTypePrompt,
        });
        const parsedDocTypeResult = parseJsonSafe(docTypeOut) || {};
        const detectedDocumentType = normalizeDocumentType(
          parsedDocTypeResult?.document_type,
          { allowEmpty: true }
        );
        const detectedLanguageFromDocType = String(
          parsedDocTypeResult?.detected_language ?? ""
        ).trim();

        const userPrompt = buildUserPrompt(cleaned);
        const out = await callOpenAI({ system: SYSTEM_PROMPT, user: userPrompt });
        return {
          cleaned,
          out,
          detectedDocumentType,
          detectedLanguageFromDocType,
        };
      })(),
      ANALYSIS_TIMEOUT_MS
    );

    reservation = await finalizeReservation(reservation.id);
    job = setAnalysisJobStatus(job.id, JOB_STATUS.SUCCESS);

    let parsedResult;
    if (typeof analysis.out === "string") {
      try {
        parsedResult = JSON.parse(analysis.out);
      } catch {
        parsedResult = { summary: analysis.out, actions: [] };
      }
    } else {
      parsedResult = analysis.out;
    }

    const parsedDocumentType = normalizeDocumentType(parsedResult?.document_type, {
      allowEmpty: true,
    });
    const normalizedDocumentType =
      requestDocumentType ||
      parsedDocumentType ||
      analysis.detectedDocumentType ||
      "unknown";
    const shouldRunRiskLabeling = normalizedDocumentType === "contract" && isProPlan;

    const summarySections = Array.isArray(parsedResult?.summary?.sections)
      ? parsedResult.summary.sections.map((section) => ({
          title: String(section?.title ?? "").trim(),
          content: String(section?.content ?? "").trim(),
        }))
      : [];
    const legacySummary = String(parsedResult?.summary ?? "").trim();
    const normalizedSummarySections =
      summarySections.length > 0
        ? summarySections
        : legacySummary
          ? [{ title: "Özet", content: legacySummary }]
          : [];

    let detectedLanguage = String(
      parsedResult?.detected_language ??
        parsedResult?.language ??
        analysis.detectedLanguageFromDocType ??
        ""
    ).trim();
    if (!detectedLanguage) {
      detectedLanguage = detectLanguageFallbackFromSummary(normalizedSummarySections);
    }
    if (!detectedLanguage) {
      detectedLanguage = "en";
    }

    const keyPoints = Array.isArray(parsedResult?.key_points)
      ? parsedResult.key_points.map((item) => String(item ?? "").trim()).filter(Boolean)
      : [];

    const actions = Array.isArray(parsedResult?.actions)
      ? parsedResult.actions.map((item, index) => ({
          id: String(item?.id ?? `A${index + 1}`),
          text: String(item?.text ?? item?.title ?? "").trim(),
        }))
      : [];

    const rawRiskItems = Array.isArray(parsedResult?.risk_analysis?.items)
      ? parsedResult.risk_analysis.items
      : Array.isArray(parsedResult?.riskAnalysis?.items)
        ? parsedResult.riskAnalysis.items
        : [];
    const riskItems = shouldRunRiskLabeling
      ? rawRiskItems.map((item) => ({
          label: String(item?.label ?? "").trim(),
          excerpt: String(item?.excerpt ?? "").trim(),
          reason: String(item?.reason ?? "").trim(),
        }))
      : [];

    let riskLabels = [];
    try {
      const riskOut = await callOpenAI({
        system: RISK_LABELING_SYSTEM_PROMPT,
        user: buildRiskLabelingPrompt(analysis.cleaned),
      });
      const parsedRisk = parseJsonSafe(riskOut) || {};
      const rawRiskLabels = Array.isArray(parsedRisk?.riskLabels)
        ? parsedRisk.riskLabels
        : Array.isArray(parsedRisk?.risk_labels)
          ? parsedRisk.risk_labels
          : [];
      riskLabels = normalizeRiskLabels(rawRiskLabels);
    } catch (riskError) {
      console.warn("[RISK_LABELS] failed:", String(riskError?.message || riskError));
      riskLabels = [];
    }

    const resultJson = {
      detected_language: detectedLanguage,
      document_type: normalizedDocumentType,
      summary: { sections: normalizedSummarySections },
      key_points: keyPoints,
      actions,
      disclaimer_short: DISCLAIMER_SHORT,
      disclaimer_long: DISCLAIMER_LONG,
      riskLabels,
      risk_analysis: {
        enabled: shouldRunRiskLabeling,
        items: riskItems,
      },
    };

    const responseJson = isProPlan
      ? resultJson
      : { ...resultJson, riskLabels: [] };
    await incrementMonthlyUsage(userId);
    setAnalyzeCache(cacheKey, resultJson);
    return res.status(200).json(responseJson);
  } catch (e) {
    const msg = String(e?.message || e);
    const upstreamStatus = getUpstreamStatusCode(msg);

    if (job) {
      job = setAnalysisJobStatus(job.id, JOB_STATUS.FAILED, msg) || job;
    }

    if (msg.includes("ANALYSIS_TIMEOUT")) {
      if (reservation?.status === RESERVATION_STATUS.RESERVED) {
        reservation = await releaseReservation(reservation.id);
      }
      return res.status(500).json({ error: "SERVER_ERROR", detail: "ANALYSIS_TIMEOUT" });
    }

    if (upstreamStatus === 429) {
      if (reservation?.status === RESERVATION_STATUS.RESERVED) {
        reservation = await releaseReservation(reservation.id);
      }
      return res.status(429).json({ error: "RATE_LIMITED", detail: "UPSTREAM_429" });
    }

    if (msg.includes("ONLY_PDF")) {
      return res.status(400).json({ error: "BAD_REQUEST", detail: "ONLY_PDF" });
    }
    if (msg.includes("LIMIT_FILE_SIZE")) {
      return res.status(413).json({ error: "PAYLOAD_TOO_LARGE", detail: "FILE_TOO_LARGE" });
    }
    if (msg.includes("PDF_TEXT_EMPTY_OR_SCANNED")) {
      return res.status(400).json({
        error: "BAD_REQUEST",
        detail: "PDF_TEXT_EMPTY_OR_SCANNED",
      });
    }
    if (msg.includes("MISSING_OPENAI_API_KEY")) {
      return res.status(500).json({ error: "SERVER_ERROR", detail: "MISSING_OPENAI_API_KEY" });
    }

    return res
      .status(upstreamStatus === 429 ? 429 : 500)
      .json({ error: upstreamStatus === 429 ? "RATE_LIMITED" : "SERVER_ERROR", detail: msg });
  } finally {
    if (reservation?.status === RESERVATION_STATUS.RESERVED) {
      const latestJob = job ? getAnalysisJob(job.id) : null;
      if (!latestJob || latestJob.status !== JOB_STATUS.SUCCESS) {
        reservation = await releaseReservation(reservation.id);
      }
    }
  }
});

const port = Number(process.env.PORT || 8787);
app.listen(port, "0.0.0.0", () => {
  console.log(`[pdf-backend] listening on http://0.0.0.0:${port}`);
});
