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

const data = JSON.parse(fs.readFileSync(collectionPath, "utf8"));
const baseUrl =
  (data.variable || []).find((v) => v.key === "url")?.value ||
  "https://app.telefreik.com";
const collectionAuth = data.auth?.type === "bearer";

const apis = [];

function getAuth(req) {
  if (req.auth?.type === "bearer") return true;
  if (req.auth?.type === "noauth") return false;
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

function walk(items, folderPath) {
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
        auth: getAuth(req),
        headers: (req.header || []).map((h) => ({
          key: h.key,
          value: h.value,
        })),
      });
    }
    if (item.item) walk(item.item, [...folderPath, name]);
  }
}

walk(data.item || [], []);

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

function slug(s) {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

function renderEndpoint(api) {
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

  const langHeader = api.headers.find((h) => h.key === "Accept-Language");
  if (langHeader) {
    lines.push(`**Headers:** \`Accept-Language: ${langHeader.value}\``);
    lines.push("");
  }

  return lines.join("\n");
}

const seen = new Map();
for (const api of apis) {
  const key = `${api.method} ${api.path}`;
  if (!api.path) continue;
  if (!seen.has(key)) seen.set(key, api.name);
}

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

  let currentSub = null;
  for (const api of sections[sec]) {
    if (api.subfolder !== currentSub) {
      if (api.subfolder) {
        md.push(`#### ${api.subfolder}`);
        md.push("");
      }
      currentSub = api.subfolder;
    }
    md.push(renderEndpoint(api));
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

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, md.join("\n"), "utf8");
console.log(`Written ${outPath}`);
console.log(`Total APIs: ${apis.length}`);
console.log(`Unique endpoints: ${seen.size}`);
