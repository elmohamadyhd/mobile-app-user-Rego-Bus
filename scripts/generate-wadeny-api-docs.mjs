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
  return { source, responses };
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
  return h?.value || "default";
}

function redactTokens(value) {
  if (value && typeof value === "object") {
    if (Array.isArray(value)) return value.map(redactTokens);
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      if (k === "api_token" && typeof v === "string") {
        out[k] = "<redacted>";
      } else {
        out[k] = redactTokens(v);
      }
    }
    return out;
  }
  return value;
}

function parseResponseBody(body) {
  if (!body || typeof body !== "string") return null;
  try {
    return JSON.parse(body);
  } catch {
    return null;
  }
}

function scenarioLabel(code, parsed) {
  const errors = parsed?.errors || {};
  const keys = Object.keys(errors);
  const message = parsed?.message || "";

  if (code === 200) {
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
    const bodyParsed = parseResponseBody(r.body);
    const redacted = bodyParsed ? redactTokens(bodyParsed) : null;
    const code = r.code ?? 0;
    const label = scenarioLabel(code, bodyParsed);
    const errorKeys = Object.keys(bodyParsed?.errors || {});

    return {
      code,
      status: r.status || "",
      language,
      label,
      errorKeys,
      bodyJson: redacted
        ? JSON.stringify(redacted, null, 2)
        : (r.body || "").trim(),
      bodyKey: redacted
        ? JSON.stringify(redacted)
        : (r.body || "").trim(),
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
    "- `Accept-Language` (`ar` / `en`) localizes `message` and `errors` text.",
  );
  lines.push(
    "- Success responses that return a session include `data.api_token` (Bearer token for subsequent calls).",
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

  if (api.headers?.length) {
    lines.push("**Headers:**");
    lines.push("");
    lines.push("| Header | Value |");
    lines.push("|--------|-------|");
    for (const h of api.headers) {
      lines.push(`| \`${h.key}\` | ${h.value} |`);
    }
    lines.push("");
  }

  const includeResponses =
    api.responses?.length > 0 &&
    (responsesMode === "all" || api.section === "Auth");
  if (includeResponses) {
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
    if (responsesMode === "all" || a.section === "Auth") {
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
  md.push("");
  md.push(
    "Nested items under Flights → Search (One Way, Round Trip, Multi City) and under Buses folders are **saved response examples**, not separate API endpoints. They all call the same endpoint as their parent request.",
  );
  md.push("");
  md.push(
    "Saved responses documented under Auth (and other folders when using `--responses=all`) are **real response examples** attached to the parent request — not separate endpoints.",
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
    .filter((a) => a.section === "Auth")
    .reduce((n, a) => n + a.responses.length, 0);
  console.log(`Auth saved responses documented: ${authResponses}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
