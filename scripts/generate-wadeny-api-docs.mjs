import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const collectionPath = path.join(
  root,
  "api postman collection",
  "Wadeny.postman_collection.....v2.json",
);
const outPath = path.join(root, "docs", "wadeny-apis.md");
const POSTMAN_COLLECTION_ID =
  "30997029-5734dbd8-5584-4709-b10d-677d91cc01aa";

function parseArgs() {
  const args = process.argv.slice(2);
  let source = "postman";
  let responses = "auth";
  for (const arg of args) {
    if (arg.startsWith("--source=")) {
      source = arg.slice("--source=".length);
    }
    if (arg.startsWith("--responses=")) {
      responses = arg.slice("--responses=".length);
    }
  }
  return { source, responses: parseResponsesMode(responses) };
}

function parseResponsesMode(raw) {
  if (raw === "all") return "all";
  return new Set(
    raw
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
      .map((s) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()),
  );
}

function shouldDocumentResponses(api, mode) {
  if (!api.responses?.length) return false;
  if (mode === "all") return true;
  return mode.has(api.section);
}

async function fetchFromPostman() {
  const apiKey = process.env.POSTMAN_API_KEY;
  if (!apiKey) {
    throw new Error(
      "POSTMAN_API_KEY is required for --source=postman. " +
        "Use --source=file to read the local collection export.",
    );
  }
  const url = `https://api.getpostman.com/collections/${POSTMAN_COLLECTION_ID}`;
  const res = await fetch(url, {
    headers: { "X-Api-Key": apiKey },
  });
  if (!res.ok) {
    throw new Error(`Postman API ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  return json.collection;
}

function loadFromFile() {
  return JSON.parse(fs.readFileSync(collectionPath, "utf8"));
}

function saveCollection(data) {
  fs.mkdirSync(path.dirname(collectionPath), { recursive: true });
  fs.writeFileSync(collectionPath, JSON.stringify(data, null, 2), "utf8");
  console.log(`Cached collection to ${collectionPath}`);
}

function getAuth(req, folderPath, collectionAuth) {
  if (req.auth?.type === "bearer") return true;
  if (req.auth?.type === "noauth") return false;
  if (folderPath.includes("Auth")) return false;
  return collectionAuth;
}

function normalizePath(raw) {
  if (!raw) return "";
  return raw.replace(/\{\{url\}\}/g, "").split("?")[0];
}

function stripJsonComments(json) {
  return json
    .replace(/\/\/[^\n]*/g, "")
    .replace(/,\s*([}\]])/g, "$1")
    .replace(/\n\s*\n/g, "\n");
}

function extractBody(body) {
  if (!body) return null;
  if (body.mode === "formdata" && body.formdata) {
    return {
      type: "formdata",
      keys: body.formdata.map((f) => f.key).filter(Boolean),
    };
  }
  if (body.mode === "raw" && body.raw) {
    let raw = body.raw.trim();
    if (raw.startsWith("{") || raw.startsWith("[")) {
      try {
        raw = JSON.stringify(JSON.parse(stripJsonComments(raw)), null, 2);
      } catch {
        raw = stripJsonComments(raw);
      }
    }
    return { type: "raw", content: raw };
  }
  return null;
}

function getLanguageFromHeaders(headers) {
  const h = (headers || []).find((x) => x.key === "Accept-Language");
  return h?.value || "ar";
}

const STANDARD_HEADER_KEYS = new Set(["accept", "accept-language"]);

function renderRequestHeaders(api) {
  const lines = [];
  lines.push("**Headers:**");
  lines.push("");
  lines.push("| Header | Value |");
  lines.push("|--------|-------|");
  lines.push("| `Accept` | application/json |");
  lines.push("| `Accept-Language` | `ar` \\| `en` (app locale) |");

  const extra = (api.headers || []).filter(
    (h) => h.key && !STANDARD_HEADER_KEYS.has(h.key.toLowerCase()),
  );
  for (const h of extra) {
    lines.push(`| \`${h.key}\` | ${h.value} |`);
  }
  lines.push("");
  return lines.join("\n");
}

function renderLocalizationSection() {
  const lines = [];
  lines.push("### Localization");
  lines.push("");
  lines.push(
    "Every request must include `Accept-Language: ar` or `Accept-Language: en`.",
  );
  lines.push("");
  lines.push(
    "The value matches the user's active app locale (Settings or device default, via `LocaleController`). REGO mobile attaches this header automatically on **all** Dio API calls.",
  );
  lines.push("");
  lines.push(
    "The backend uses it to localize `message`, `errors`, and localized content in responses. Supported values: `ar` (primary), `en`.",
  );
  lines.push("");
  return lines.join("\n");
}

function redactTokens(value) {
  if (value && typeof value === "object") {
    if (Array.isArray(value)) return value.map(redactTokens);
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      if (k === "api_token" && typeof v === "string") {
        out[k] = "<redacted>";
      } else if (
        (k === "invoice_url" || k === "payment_url") &&
        typeof v === "string"
      ) {
        out[k] = v.replace(/\/[^/]+$/, "/…");
      } else {
        out[k] = redactTokens(v);
      }
    }
    return out;
  }
  return value;
}

function isHtmlBody(body) {
  if (!body || typeof body !== "string") return false;
  const trimmed = body.trim();
  return trimmed.startsWith("<!DOCTYPE") || trimmed.startsWith("<html");
}

function truncateArrays(value, maxItems = 3) {
  if (Array.isArray(value)) {
    if (value.length <= maxItems) {
      return value.map((item) => truncateArrays(item, maxItems));
    }
    const truncated = value
      .slice(0, maxItems)
      .map((item) => truncateArrays(item, maxItems));
    truncated.push(`…${value.length - maxItems} more items`);
    return truncated;
  }
  if (value && typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = truncateArrays(v, maxItems);
    }
    return out;
  }
  return value;
}

function stripLaravelTrace(parsed) {
  if (!parsed || typeof parsed !== "object") return parsed;
  if (parsed.exception && parsed.trace) {
    const { message, exception, file, line } = parsed;
    return { message, exception, file, line };
  }
  return parsed;
}

function sanitizeResponseBody(bodyParsed, rawBody) {
  if (!bodyParsed) {
    if (isHtmlBody(rawBody)) {
      return {
        sanitized: null,
        bodyJson: null,
        isHtml: true,
      };
    }
    return {
      sanitized: null,
      bodyJson: (rawBody || "").trim(),
      isHtml: false,
    };
  }

  let sanitized = redactTokens(bodyParsed);
  sanitized = stripLaravelTrace(sanitized);
  sanitized = truncateArrays(sanitized);

  return {
    sanitized,
    bodyJson: JSON.stringify(sanitized, null, 2),
    isHtml: false,
  };
}

function parseResponseBody(body) {
  if (!body || typeof body !== "string") return null;
  try {
    return JSON.parse(body);
  } catch {
    return null;
  }
}

function scenarioLabel(code, parsed, rawBody) {
  const errors = parsed?.errors || {};
  const keys = Object.keys(errors);
  const message = parsed?.message || "";

  if (isHtmlBody(rawBody)) return "Not found (HTML)";

  if (code === 401 || message === "Unauthenticated") return "Unauthenticated";

  if (parsed?.exception && code === 500) return "Server error";

  if (code === 200) {
    if (Array.isArray(parsed?.data) && parsed.data.length === 0) {
      return "Empty results";
    }
    if (message.toLowerCase().includes("locations list")) {
      return "Locations list";
    }
    if (message.toLowerCase().includes("carriers list")) {
      return "Carriers list";
    }
    if (message.toLowerCase().includes("trips list")) {
      return "Trips list";
    }
    if (message.toLowerCase().includes("salons seats")) {
      return "Seat map";
    }
    if (message.toLowerCase().includes("order created")) {
      return "Order created";
    }
    if (message.toLowerCase().includes("order details")) {
      return "Order details";
    }
    if (parsed?.data?.api_token) return "Success — user data";
    if (
      message.toLowerCase().includes("logged in") ||
      message.toLowerCase().includes("user data")
    ) {
      return "Success — logged in";
    }
    if (message.toLowerCase().includes("valid code")) {
      return "Success — valid code";
    }
    if (
      message.includes("تحقيق") ||
      message.toLowerCase().includes("verification") ||
      message.toLowerCase().includes("otp")
    ) {
      return "Success — OTP sent";
    }
    if (
      message.includes("كلمة المرور") ||
      message.toLowerCase().includes("password")
    ) {
      return "Success — password updated";
    }
  }

  if (keys.includes("from_location_id") || keys.includes("to_location_id")) {
    return "Missing location IDs";
  }
  if (keys.includes("credentials")) return "Invalid credentials";
  if (keys.includes("mobile") && code === 404) return "Record not found";
  if (keys.includes("mobile") && code === 400 && !keys.includes("email")) {
    return "Mobile not registered";
  }
  if (keys.includes("code")) return "Invalid verification code";
  if (keys.includes("email") && keys.includes("mobile")) {
    return "Email and mobile already taken";
  }
  if (keys.includes("email")) return "Email already taken";
  if (keys.includes("mobile")) return "Mobile already taken";
  if (keys.includes("password")) return "Password confirmation mismatch";
  if (code === 404) return "Record not found";

  const short =
    message.length > 50 ? `${message.slice(0, 47)}...` : message;
  return short || `HTTP ${code}`;
}

function parseSavedResponses(rawResponses) {
  const parsed = (rawResponses || []).map((r) => {
    const headers = r.originalRequest?.header || [];
    const language = getLanguageFromHeaders(headers);
    const rawBody = (r.body || "").trim();
    const bodyParsed = parseResponseBody(r.body);
    const { sanitized, bodyJson, isHtml } = sanitizeResponseBody(
      bodyParsed,
      rawBody,
    );
    const code = r.code ?? 0;
    const label = scenarioLabel(code, bodyParsed, rawBody);
    const errorKeys = Object.keys(bodyParsed?.errors || {});

    return {
      code,
      status: r.status || "",
      language,
      label,
      errorKeys,
      isHtml,
      bodyJson: isHtml
        ? null
        : bodyJson,
      bodyKey: isHtml
        ? `html|${code}|${label}`
        : sanitized
          ? JSON.stringify(sanitized)
          : rawBody,
    };
  });

  const seen = new Map();
  const deduped = [];
  for (const r of parsed) {
    const key = `${r.code}|${r.language}|${r.bodyKey}`;
    if (seen.has(key)) {
      seen.get(key).count += 1;
      continue;
    }
    const entry = { ...r, count: 1 };
    seen.set(key, entry);
    deduped.push(entry);
  }
  return deduped;
}

function walk(items, folderPath, collectionAuth, apis) {
  for (const item of items) {
    const name = item.name || "";
    if (item.request) {
      const req = item.request;
      const url = req.url;
      const raw = typeof url === "string" ? url : url?.raw || "";
      const query = typeof url === "object" && url?.query ? url.query : [];
      const pathOnly = normalizePath(raw);
      const parts = folderPath.filter((p) => p !== "V1");
      const section =
        parts[0] || (folderPath.includes("V1") ? name : "Other");
      const subfolder = parts.length > 1 ? parts.slice(1).join(" > ") : null;

      apis.push({
        section,
        subfolder,
        folder: folderPath.join(" > "),
        name,
        method: req.method || "GET",
        rawUrl: raw,
        path: pathOnly,
        query,
        body: extractBody(req.body),
        auth: getAuth(req, folderPath, collectionAuth),
        headers: (req.header || []).map((h) => ({
          key: h.key,
          value: h.value,
        })),
        responses: parseSavedResponses(item.response),
      });
    }
    if (item.item) walk(item.item, [...folderPath, name], collectionAuth, apis);
  }
}

function slug(s) {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

function renderAuthEnvelope() {
  const lines = [];
  lines.push("### Response envelope");
  lines.push("");
  lines.push(
    "All Auth endpoints return JSON with this shape (HTTP status may differ from the inner `status` field):",
  );
  lines.push("");
  lines.push("```json");
  lines.push(
    JSON.stringify(
      {
        status: 200,
        message: "…",
        errors: { field: "…" },
        data: {},
      },
      null,
      2,
    ),
  );
  lines.push("```");
  lines.push("");
  lines.push(
    "- `errors` values are **strings** in live responses; the mobile app normalizes strings and arrays.",
  );
  lines.push(
    "- All endpoints honor `Accept-Language`; Auth saved examples below show `ar` and `en` variants where captured in Postman.",
  );
  lines.push(
    "- Success responses that return a session include `data.api_token` (Bearer token for subsequent calls).",
  );
  lines.push("");
  return lines.join("\n");
}

function renderBusesEnvelope() {
  const lines = [];
  lines.push("### Response envelope");
  lines.push("");
  lines.push(
    "All Buses endpoints return JSON with this shape (HTTP status may differ from the inner `status` field):",
  );
  lines.push("");
  lines.push("```json");
  lines.push(
    JSON.stringify(
      {
        status: 200,
        message: "…",
        errors: {},
        data: {},
      },
      null,
      2,
    ),
  );
  lines.push("```");
  lines.push("");
  lines.push(
    "- List endpoints (`locations`, `stations`, `carriers`, `trips`) return `data` as an **array**.",
  );
  lines.push(
    "- `search trips` also includes a top-level `pagination` object.",
  );
  lines.push(
    "- `seats` and `create-ticket` return `data` as an **object** (seat map / order).",
  );
  lines.push(
    "- `errors` values are **strings** in live responses; the mobile app normalizes strings and arrays.",
  );
  lines.push("");
  return lines.join("\n");
}

function renderResponses(api) {
  if (!api.responses?.length) return "";

  const lines = [];
  lines.push("**Saved responses:**");
  lines.push("");
  lines.push("| HTTP | Scenario | Language | Error fields |");
  lines.push("|------|----------|----------|--------------|");
  for (const r of api.responses) {
    const errCol =
      r.errorKeys.length > 0
        ? r.errorKeys.map((k) => `\`${k}\``).join(", ")
        : "—";
    const scenario =
      r.count > 1 ? `${r.label} (×${r.count})` : r.label;
    lines.push(
      `| \`${r.code}\` | ${scenario} | ${r.language} | ${errCol} |`,
    );
  }
  lines.push("");

  for (const r of api.responses) {
    const heading = `${r.code} — ${r.label} (${r.language})`;
    lines.push(`#### ${heading}`);
    lines.push("");
    if (r.isHtml) {
      lines.push(
        "_404 HTML page returned — stale example URL in Postman (`originalRequest` may point to a removed path)._",
      );
      lines.push("");
      continue;
    }
    lines.push("```json");
    lines.push(r.bodyJson);
    lines.push("```");
    lines.push("");
  }

  return lines.join("\n");
}

function renderEndpoint(api, responsesMode) {
  const lines = [];
  lines.push(`### ${api.name}`);
  lines.push("");
  lines.push("| | |");
  lines.push("|---|---|");
  lines.push(`| **Method** | \`${api.method}\` |`);
  lines.push(
    `| **Path** | \`${api.path || "*(not configured)*"}\` |`,
  );
  lines.push(
    `| **Full URL** | \`${api.rawUrl ? api.rawUrl.replace(/\{\{url\}\}/g, baseUrl) : "*(not configured)*"}\` |`,
  );
  lines.push(
    `| **Auth** | ${api.auth ? "Bearer token required" : "No (public)"} |`,
  );
  if (api.subfolder) {
    lines.push(`| **Folder** | ${api.subfolder} |`);
  }
  lines.push("");

  if (api.query?.length) {
    lines.push("**Query parameters:**");
    lines.push("");
    lines.push("| Parameter | Example |");
    lines.push("|-----------|---------|");
    for (const q of api.query) {
      lines.push(`| \`${q.key}\` | ${q.value || ""} |`);
    }
    lines.push("");
  }

  if (api.body) {
    if (api.body.type === "formdata") {
      lines.push(
        `**Body (form-data):** ${api.body.keys.map((k) => `\`${k}\``).join(", ")}`,
      );
      lines.push("");
    } else if (api.body.type === "raw") {
      lines.push("**Body (JSON):**");
      lines.push("");
      lines.push("```json");
      lines.push(api.body.content);
      lines.push("```");
      lines.push("");
    }
  }

  lines.push(renderRequestHeaders(api));

  if (shouldDocumentResponses(api, responsesMode)) {
    const responsesBlock = renderResponses(api);
    if (responsesBlock) lines.push(responsesBlock);
  }

  return lines.join("\n");
}

function generateMarkdown(data, apis, baseUrl, responsesMode) {
  const sections = {};
  const sectionOrder = [
    "Auth",
    "Profile",
    "Content",
    "Flights",
    "Private",
    "Buses",
    "Currencies",
  ];
  for (const api of apis) {
    if (!sections[api.section]) sections[api.section] = [];
    sections[api.section].push(api);
  }

  const seen = new Map();
  for (const api of apis) {
    const key = `${api.method} ${api.path}`;
    if (!api.path) continue;
    if (!seen.has(key)) seen.set(key, api.name);
  }

  const totalSavedResponses = apis.reduce((n, a) => {
    if (shouldDocumentResponses(a, responsesMode)) {
      return n + (a.responses?.length || 0);
    }
    return n;
  }, 0);

  const md = [];
  md.push("# Wadeny API Reference (v1)");
  md.push("");
  md.push(
    "> Generated from [`Wadeny.postman_collection.....v2.json`](../api%20postman%20collection/Wadeny.postman_collection.....v2.json)",
  );
  md.push("");
  md.push("## Overview");
  md.push("");
  md.push("| Property | Value |");
  md.push("|----------|-------|");
  md.push(`| **Base URL** | \`${baseUrl}\` |`);
  md.push("| **Collection** | Wadeny |");
  md.push("| **Default auth** | Bearer token (`{{token}}`) |");
  md.push("| **Content-Type** | `application/json` (most endpoints) |");
  md.push(`| **Total requests** | ${apis.length} |`);
  md.push(`| **Documented saved responses** | ${totalSavedResponses} |`);
  md.push("");
  md.push(
    "Public endpoints (no auth): Auth group (login, register, OTP, password reset) and most Content endpoints.",
  );
  md.push("");
  md.push(renderLocalizationSection());
  md.push("## Quick reference (unique endpoints)");
  md.push("");
  md.push("| Method | Path | Example name |");
  md.push("|--------|------|--------------|");
  for (const [key, name] of [...seen.entries()].sort()) {
    const spaceIdx = key.indexOf(" ");
    const method = key.slice(0, spaceIdx);
    const pathPart = key.slice(spaceIdx + 1);
    md.push(`| \`${method}\` | \`${pathPart}\` | ${name} |`);
  }
  md.push("");
  md.push("## Table of contents");
  md.push("");
  for (const sec of sectionOrder) {
    if (sections[sec]) {
      md.push(
        `- [${sec}](#${slug(sec)}) (${sections[sec].length} requests)`,
      );
    }
  }
  md.push("- [Collection issues](#collection-issues)");
  md.push("");

  for (const sec of sectionOrder) {
    if (!sections[sec]) continue;
    md.push(`## ${sec}`);
    md.push("");
    md.push("| # | Method | Path | Name |");
    md.push("|---|--------|------|------|");
    sections[sec].forEach((api, i) => {
      md.push(
        `| ${i + 1} | \`${api.method}\` | \`${api.path || "—"}\` | ${api.name} |`,
      );
    });
    md.push("");

    if (sec === "Auth") {
      md.push(renderAuthEnvelope());
    }

    if (sec === "Buses") {
      md.push(renderBusesEnvelope());
    }

    let currentSub = null;
    for (const api of sections[sec]) {
      if (api.subfolder !== currentSub) {
        if (api.subfolder) {
          md.push(`#### ${api.subfolder}`);
          md.push("");
        }
        currentSub = api.subfolder;
      }
      md.push(renderEndpoint(api, responsesMode));
    }
  }

  md.push("## Collection issues");
  md.push("");
  md.push(
    "The following inconsistencies exist in the Postman collection and may not reflect the real API:",
  );
  md.push("");
  md.push("| Item | Issue |");
  md.push("|------|-------|");
  md.push("| Content → New Request | No URL configured (empty request) |");
  md.push(
    "| Private → Show Trip Details | URL points to `/flights/airports/search` instead of a private trip endpoint |",
  );
  md.push(
    '| Currencies | Named "Currencies" but URL is `/flights/iata?search=CAI` — likely copy-paste error |',
  );
  md.push(
    "| Profile → Orders → Flights → Show | Same URL as List (`/profile/orders/flights`) — Show may need `/{id}` |",
  );
  md.push(
    "| Buses saved examples | Some `originalRequest` URLs still point to legacy `/api/transports/*` paths — response bodies are valid; request snapshots are stale |",
  );
  md.push(
    "| Buses → Create Ticket (500) | Known backend bug in `PayMobPayAction` (`Undefined array key \"url\"`) — not a client contract |",
  );
  md.push(
    "| Buses → Search details (404 HTML) | Saved example returned an HTML 404 page — likely captured against a removed trip ID |",
  );
  md.push("");
  md.push(
    "Nested items under Flights → Search (One Way, Round Trip, Multi City) and under Buses folders are **saved response examples**, not separate API endpoints. They all call the same endpoint as their parent request.",
  );
  md.push("");
  md.push(
    "Saved responses documented under Auth and Buses (and other folders when using `--responses=all`) are **real response examples** attached to the parent request — not separate endpoints.",
  );
  md.push("");

  return { md: md.join("\n"), apis, seen };
}

let baseUrl;

async function main() {
  const { source, responses } = parseArgs();
  let data;

  if (source === "postman") {
    console.log(`Fetching collection ${POSTMAN_COLLECTION_ID} from Postman…`);
    data = await fetchFromPostman();
    saveCollection(data);
  } else if (source === "file") {
    console.log(`Reading collection from ${collectionPath}`);
    data = loadFromFile();
  } else {
    throw new Error(`Unknown --source=${source}. Use postman or file.`);
  }

  baseUrl =
    (data.variable || []).find((v) => v.key === "url")?.value ||
    "https://app.telefreik.com";
  const collectionAuth = data.auth?.type === "bearer";

  const apis = [];
  walk(data.item || [], [], collectionAuth, apis);

  const { md, seen } = generateMarkdown(data, apis, baseUrl, responses);

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, md, "utf8");
  console.log(`Written ${outPath}`);
  console.log(`Total APIs: ${apis.length}`);
  console.log(`Unique endpoints: ${seen.size}`);
  const authResponses = apis
    .filter((a) => a.section === "Auth" && shouldDocumentResponses(a, responses))
    .reduce((n, a) => n + a.responses.length, 0);
  const busResponses = apis
    .filter((a) => a.section === "Buses" && shouldDocumentResponses(a, responses))
    .reduce((n, a) => n + a.responses.length, 0);
  console.log(`Auth saved responses documented: ${authResponses}`);
  console.log(`Buses saved responses documented: ${busResponses}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
