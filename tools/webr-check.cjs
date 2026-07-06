#!/usr/bin/env node

const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");
const zlib = require("zlib");
const { execFileSync } = require("child_process");
const { WebR, ChannelType } = require("webr");

const tgzPath = path.resolve(process.argv[2] || process.env.RBEBELM_WEBR_TGZ || "");
if (!tgzPath || !fs.existsSync(tgzPath)) {
  console.error("Usage: node tools/webr-check.cjs path/to/Rbebelm_<version>.tgz");
  process.exit(2);
}

function parseDcf(text) {
  const fields = {};
  let current = null;
  for (const line of text.split(/\r?\n/)) {
    if (!line) continue;
    if (/^\s/.test(line) && current) {
      fields[current] += `\n${line}`;
      continue;
    }
    const idx = line.indexOf(":");
    if (idx < 0) continue;
    current = line.slice(0, idx);
    fields[current] = line.slice(idx + 1).replace(/^\s*/, "");
  }
  return fields;
}

function packageFieldsForArchive(archivePath, extractRoot, index) {
  const extractDir = path.join(extractRoot, `extract-${index}`);
  fs.mkdirSync(extractDir, { recursive: true });
  execFileSync("tar", ["-xzf", archivePath, "-C", extractDir], { stdio: "inherit" });
  const dirs = fs.readdirSync(extractDir).filter((name) => fs.existsSync(path.join(extractDir, name, "DESCRIPTION")));
  if (!dirs.length) throw new Error(`Could not find DESCRIPTION in ${archivePath}`);
  const fields = parseDcf(fs.readFileSync(path.join(extractDir, dirs[0], "DESCRIPTION"), "utf8"));
  if (!fields.Package || !fields.Version) throw new Error(`Unexpected DESCRIPTION in ${archivePath}`);
  fields.File = path.basename(archivePath);
  return fields;
}

function writePackagesIndex(repoDir, packageEntries) {
  fs.mkdirSync(repoDir, { recursive: true });
  for (const entry of packageEntries) {
    fs.copyFileSync(entry.archivePath, path.join(repoDir, path.basename(entry.archivePath)));
  }
  const packages = packageEntries
    .map((entry) => {
      const fields = { ...entry.fields, File: path.basename(entry.archivePath) };
      const keys = Object.keys(fields).filter((key) => fields[key] !== undefined && fields[key] !== "");
      return keys.map((key) => `${key}: ${fields[key]}`).join("\n");
    })
    .join("\n\n") + "\n";
  fs.writeFileSync(path.join(repoDir, "PACKAGES"), packages);
  fs.writeFileSync(path.join(repoDir, "PACKAGES.gz"), zlib.gzipSync(packages));
}

function createLocalRepo(tmpRoot, rSeries) {
  const archiveDir = path.dirname(tgzPath);
  const archives = fs.readdirSync(archiveDir)
    .filter((file) => file.endsWith(".tgz"))
    .map((file) => path.join(archiveDir, file));
  if (!archives.includes(tgzPath)) archives.push(tgzPath);

  const extractRoot = path.join(tmpRoot, "extract");
  const packageEntries = archives.map((archivePath, index) => ({
    archivePath,
    fields: packageFieldsForArchive(archivePath, extractRoot, index),
  }));
  if (!packageEntries.some((entry) => entry.fields.Package === "Rbebelm")) {
    throw new Error(`Local repo does not include Rbebelm archive ${tgzPath}`);
  }

  writePackagesIndex(path.join(tmpRoot, "repo", "src", "contrib"), packageEntries);
  writePackagesIndex(path.join(tmpRoot, "repo", "bin", "emscripten", "contrib", rSeries), packageEntries);
  return path.join(tmpRoot, "repo");
}

function contentType(filePath) {
  if (filePath.endsWith(".gz") || filePath.endsWith(".tgz")) return "application/gzip";
  if (filePath.endsWith(".rds")) return "application/octet-stream";
  return "text/plain; charset=utf-8";
}

function serveDirectory(root) {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    const decoded = decodeURIComponent(url.pathname).replace(/^\/+/, "");
    const filePath = path.normalize(path.join(root, decoded));
    if (!filePath.startsWith(root)) {
      res.writeHead(403);
      res.end("forbidden");
      return;
    }
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("not found");
        return;
      }
      res.writeHead(200, { "content-type": contentType(filePath) });
      res.end(data);
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function outputText(capture) {
  return (capture.output || [])
    .map((entry) => (typeof entry.data === "string" ? entry.data : ""))
    .filter(Boolean)
    .join("\n");
}

(async () => {
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "rbebelm-webr-"));
  let server;
  let webR;
  try {
    webR = new WebR({ channelType: ChannelType.PostMessage, interactive: false });
    await webR.init();
    const [major, minor] = (webR.versionR || "4.5.0").split(".");
    const repoRoot = createLocalRepo(tmpRoot, `${major}.${minor}`);
    server = await serveDirectory(repoRoot);
    const repoUrl = `http://127.0.0.1:${server.address().port}`;

    console.log(`webR ${webR.version}; R ${webR.versionR}`);
    await webR.installPackages(["Rbebelm"], {
      repos: [repoUrl, "https://repo.r-wasm.org"],
      mount: false,
    });

    const shelter = await new webR.Shelter();
    const capture = await shelter.captureR(`
library(Rbebelm)
stopifnot(requireNamespace("S7", quietly = TRUE))
info <- rbebelm_backend_info()
print(info)
stopifnot(identical(info$dispatch_mode, "static"))
stopifnot(identical(info$installed_backends, "wasm_simd128"))
stopifnot(identical(info$supported_backends, "wasm_simd128"))
features <- rbebelm_backend_features()
print(features)
info2 <- rbebelm_backend_info()
stopifnot(identical(info2$selected_backend, "wasm_simd128"))
stopifnot(isTRUE(info2$backend_loaded))
stopifnot(identical(features$backend, "wasm_simd128"))
stopifnot(identical(features$target_arch, "wasm32"))
stopifnot(identical(features$target_os, "emscripten"))
stopifnot(identical(features$model_storage, "shared_arc_mmap"))
stopifnot("tool_call_end" %in% bebel_event_types())
load_error <- tryCatch({ bebel_model_load("/missing-model.gguf"); "" }, error = function(e) conditionMessage(e))
stopifnot(nzchar(load_error))
stopifnot(!grepl("unsupported", load_error, ignore.case = TRUE))
ids <- bebel_token_ids()
stopifnot(ids["TOKEN_TOOL_CALL_START"] > 0L)
call <- bebel_parse_tool_call('echo({"x": 1})')
stopifnot(identical(call$name, "echo"))
tool <- bebel_tool("echo", function(args, context, call) args)
stopifnot(S7::S7_inherits(tool, BebelToolSpec))
`, { withAutoprint: false });
    const text = outputText(capture);
    if (text) console.log(text);
    console.log("PASS Rbebelm webR check");
    await webR.close();
  } finally {
    if (server) server.close();
    if (webR) webR.close();
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
