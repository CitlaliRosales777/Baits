import "dotenv/config";
import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createLabState, addEvent, publicSnapshot } from "./lab-state.js";
import { MongoService } from "./mongo-service.js";
import { agentStatus, invokeAgent } from "./agent-client.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.resolve(__dirname, "../public");
const mode = "live";
const port = Number(process.env.PORT || 4173);
const nodes = parseNodes(process.env.LAB_NODES_JSON);
const state = createLabState(nodes);
const mongo = process.env.MONGO_URI
  ? new MongoService(process.env.MONGO_URI, process.env.MONGO_DB || "moodsitto_lab")
  : null;

const app = express();
app.disable("x-powered-by");
app.use(express.json({ limit: "64kb" }));
app.use(express.static(publicDir, { etag: true, maxAge: 0 }));

app.get("/api/health", (_request, response) => {
  response.json({ ok: true, mode, time: new Date().toISOString() });
});

app.get("/api/overview", async (_request, response, next) => {
  try {
    await refreshLiveState();
    response.json(publicSnapshot(state));
  } catch (error) {
    next(error);
  }
});

app.get("/api/records", async (_request, response, next) => {
  try {
    requireMongo();
    response.json(await mongo.listRecords());
  } catch (error) {
    next(error);
  }
});

app.post("/api/records", async (request, response, next) => {
  try {
    const input = validateRecord(request.body);
    requireMongo();
    const record = await mongo.createRecord(input);
    state.writes += 1;
    addEvent(state, "CRUD", `CREATE confirmado por mayoria: ${record.patient}`, "success");
    response.status(201).json(record);
  } catch (error) {
    next(error);
  }
});

app.patch("/api/records/:id", async (request, response, next) => {
  try {
    const input = validateRecord(request.body);
    requireMongo();
    const record = await mongo.updateRecord(request.params.id, input);
    state.writes += 1;
    addEvent(state, "CRUD", `UPDATE replicado: ${record.patient}`, "success");
    response.json(record);
  } catch (error) {
    next(error);
  }
});

app.delete("/api/records/:id", async (request, response, next) => {
  try {
    requireMongo();
    const deleted = await mongo.deleteRecord(request.params.id);
    if (!deleted) throw httpError(404, "Registro no encontrado");
    state.writes += 1;
    addEvent(state, "CRUD", "DELETE confirmado por mayoria", "success");
    response.status(204).end();
  } catch (error) {
    next(error);
  }
});

app.post("/api/tests", async (request, response, next) => {
  try {
    const type = String(request.body?.type || "");
    const nodeId = request.body?.nodeId ? String(request.body.nodeId) : undefined;
    const allowed = new Set(["secondary-down", "primary-failover", "write-retry", "quorum-loss"]);
    if (!allowed.has(type)) throw httpError(400, "Tipo de prueba no valido");

    if (process.env.ALLOW_LIVE_CHAOS !== "true") {
      throw httpError(403, "Las pruebas reales estan bloqueadas. Configura ALLOW_LIVE_CHAOS=true despues de validar los agentes.");
    }
    if (type === "quorum-loss" && process.env.ALLOW_QUORUM_TESTS !== "true") {
      throw httpError(403, "La perdida de quorum requiere ALLOW_QUORUM_TESTS=true");
    }
    const test = await startLiveTest(type, nodeId);
    response.status(202).json(test);
  } catch (error) {
    next(error);
  }
});

app.post("/api/recover", async (_request, response, next) => {
  try {
    const token = process.env.LAB_AGENT_TOKEN || "";
    const results = await Promise.allSettled(state.nodes.filter((node) => node.agentUrl).map((node) => invokeAgent(node, "start", token)));
    addEvent(state, "Orquestador", "Orden de recuperacion enviada a todos los agentes", "success");
    response.json({ ok: true, results: results.map((item) => item.status) });
  } catch (error) {
    next(error);
  }
});

app.get("*splat", (_request, response) => response.sendFile(path.join(publicDir, "index.html")));

app.use((error, _request, response, _next) => {
  const status = Number(error.status || 500);
  if (status >= 500) console.error(error);
  response.status(status).json({ error: error.message || "Error interno" });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Moodsitto Administracion: http://localhost:${port} [real]`);
});

async function refreshLiveState() {
  const token = process.env.LAB_AGENT_TOKEN || "";
  const statuses = await Promise.all(state.nodes.map((node) => agentStatus(node, token)));
  statuses.forEach((status, index) => {
    state.nodes[index].agentAvailable = status.available;
    if (status.service === "running") state.nodes[index].status = "online";
    if (status.service === "stopped") state.nodes[index].status = "offline";
    state.nodes[index].lastSeen = new Date().toISOString();
  });

  if (!mongo) {
    addEvent(state, "Monitor", "MONGO_URI no esta configurado", "danger");
    return;
  }
  try {
    const topology = await mongo.topology();
    const members = topology.status?.members || [];
    for (const node of state.nodes) {
      const member = members.find((item) => item.name?.startsWith(`${node.host}:`) || item.name?.startsWith(`${node.mongoHost || node.name}:`));
      if (member) {
        node.role = member.stateStr;
        node.status = member.health === 1 ? "online" : "offline";
        node.latencyMs = Math.max(1, Math.round((member.pingMs ?? 0) * 10) / 10);
      }
    }
  } catch (error) {
    addEvent(state, "Monitor", `No fue posible leer el replica set: ${error.message}`, "danger");
  }
}

async function startLiveTest(type, nodeId) {
  if (state.activeTest) throw httpError(409, "Ya existe una prueba en curso");
  const primary = state.nodes.find((node) => node.role === "PRIMARY");
  const secondary = state.nodes.find((node) => node.role === "SECONDARY");
  const requested = state.nodes.find((node) => node.id === nodeId);
  const targets = type === "quorum-loss"
    ? state.nodes.filter((node) => node.id !== primary?.id).slice(0, 2)
    : [requested || (type === "secondary-down" ? secondary : primary)].filter(Boolean);
  if (!targets.length || (type === "quorum-loss" && targets.length < 2)) throw httpError(409, "No se encontraron nodos adecuados");
  const missingAgent = targets.find((node) => !node.agentUrl);
  if (missingAgent) throw httpError(409, `${missingAgent.name} no tiene agente configurado`);

  const testId = crypto.randomUUID();
  state.activeTest = { id: testId, type, nodeIds: targets.map((node) => node.id), startedAt: new Date().toISOString(), phase: "stopping" };
  addEvent(state, "Orquestador", `Prueba real iniciada sobre ${targets.map((node) => node.name).join(", ")}`, "warning", { testId });
  await Promise.all(targets.map((node) => invokeAgent(node, "stop", process.env.LAB_AGENT_TOKEN || "")));
  for (const node of targets) {
    node.status = "offline";
    node.role = "UNKNOWN";
    addEvent(state, node.name, "Agente confirmo MongoDB detenido", "danger", { testId });
  }

  if (type === "write-retry") runWriteProbe(testId, false);
  if (type === "quorum-loss") runWriteProbe(testId, true);

  const recoverySeconds = Math.max(10, Number(process.env.AUTO_RECOVERY_SECONDS || 25));
  setTimeout(async () => {
    try {
      await Promise.all(targets.map((node) => invokeAgent(node, "start", process.env.LAB_AGENT_TOKEN || "")));
      for (const node of targets) addEvent(state, node.name, "Recuperacion automatica confirmada", "success", { testId });
    } catch (error) {
      addEvent(state, "Orquestador", `Fallo la recuperacion automatica: ${error.message}`, "danger", { testId });
    } finally {
      state.activeTest = null;
    }
  }, recoverySeconds * 1000);
  return state.activeTest;
}

async function runWriteProbe(testId, expectFailure) {
  try {
    requireMongo();
    const id = await mongo.createProbe(`test-${testId}`);
    state.writes += 1;
    addEvent(state, "MongoDB", `Escritura de prueba confirmada: ${id}`, expectFailure ? "danger" : "success", { testId });
  } catch (error) {
    state.retries += 1;
    addEvent(state, "MongoDB", expectFailure ? "Escritura bloqueada sin quorum" : `Escritura no confirmada: ${error.message}`, expectFailure ? "success" : "danger", { testId });
  }
}

function validateRecord(body) {
  const patient = String(body?.patient || "").trim();
  const mood = String(body?.mood || "").trim();
  const note = String(body?.note || "").trim();
  const score = Number(body?.score);
  if (patient.length < 2 || patient.length > 80) throw httpError(400, "El caso debe tener entre 2 y 80 caracteres");
  if (mood.length < 2 || mood.length > 40) throw httpError(400, "La emocion debe tener entre 2 y 40 caracteres");
  if (!Number.isFinite(score) || score < 1 || score > 10) throw httpError(400, "La intensidad debe estar entre 1 y 10");
  if (note.length > 240) throw httpError(400, "La nota no puede exceder 240 caracteres");
  return { patient, mood, score, note };
}

function parseNodes(raw) {
  const fallback = [
    { id: "linux", name: "lvltechmx", host: "100.94.145.63", mongoHost: "lvltechmx", os: "linux", priority: 2, agentUrl: "" },
    { id: "desktop", name: "desktop-smecf2n", host: "100.89.172.17", mongoHost: "desktop-smecf2n", os: "windows", priority: 1, agentUrl: "" },
    { id: "laptop", name: "desktop-0ddrldi", host: "100.86.5.50", mongoHost: "desktop-0ddrldi", os: "windows", priority: 0, agentUrl: "" }
  ];
  if (!raw) return fallback;
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) && parsed.length >= 3 ? parsed : fallback;
  } catch {
    return fallback;
  }
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function requireMongo() {
  if (!mongo) throw httpError(503, "MongoDB real no esta configurado. Define MONGO_URI en .env.");
}
