import dotenv from "dotenv";
import express from "express";
import crypto from "node:crypto";
import os from "node:os";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

dotenv.config({ path: fileURLToPath(new URL(".env", import.meta.url)) });

const execFileAsync = promisify(execFile);
const app = express();
const port = Number(process.env.AGENT_PORT || 4318);
const host = process.env.AGENT_HOST || "0.0.0.0";
const token = process.env.LAB_AGENT_TOKEN || "";
const serviceName = process.env.MONGODB_SERVICE || (process.platform === "win32" ? "MongoDB" : "mongod");

if (token.length < 20) {
  console.error("LAB_AGENT_TOKEN debe contener al menos 20 caracteres");
  process.exit(1);
}

app.disable("x-powered-by");
app.use(express.json({ limit: "8kb" }));
app.get("/health", (_request, response) => response.json({ ok: true, node: os.hostname() }));
app.use(authorize);

app.get("/status", async (_request, response, next) => {
  try {
    response.json({ node: os.hostname(), service: await serviceStatus(), platform: process.platform, at: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
});

app.post("/service/:action", async (request, response, next) => {
  try {
    const action = request.params.action;
    if (!new Set(["start", "stop", "restart"]).has(action)) return response.status(400).json({ error: "Accion no permitida" });
    await controlService(action);
    response.json({ ok: true, action, node: os.hostname(), service: await serviceStatus(), at: new Date().toISOString() });
  } catch (error) {
    next(error);
  }
});

app.use((error, _request, response, _next) => {
  console.error(error);
  response.status(500).json({ error: error.message || "Error del agente" });
});

app.listen(port, host, () => console.log(`Moodsitto lab agent en http://${host}:${port} para ${serviceName}`));

function authorize(request, response, next) {
  const received = request.headers.authorization?.replace(/^Bearer\s+/i, "") || "";
  const expectedBuffer = Buffer.from(token);
  const receivedBuffer = Buffer.from(received);
  if (receivedBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(receivedBuffer, expectedBuffer)) {
    return response.status(401).json({ error: "No autorizado" });
  }
  next();
}

async function serviceStatus() {
  if (process.platform === "win32") {
    const script = `(Get-Service -Name '${serviceName}' -ErrorAction Stop).Status.ToString().ToLowerInvariant()`;
    const { stdout } = await execFileAsync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], { windowsHide: true });
    return stdout.trim() === "running" ? "running" : "stopped";
  }
  const result = await execFileAsync("systemctl", ["is-active", serviceName]).catch((error) => ({ stdout: error.stdout || "inactive" }));
  return result.stdout.trim() === "active" ? "running" : "stopped";
}

async function controlService(action) {
  if (process.platform === "win32") {
    const command = action === "restart" ? "Restart-Service" : action === "start" ? "Start-Service" : "Stop-Service";
    const force = action === "start" ? "" : " -Force";
    await execFileAsync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", `${command} -Name '${serviceName}'${force} -ErrorAction Stop`], { windowsHide: true });
    return;
  }
  await execFileAsync("systemctl", [action, serviceName]);
}
