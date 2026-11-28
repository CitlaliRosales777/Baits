const state = {
  overview: null,
  records: [],
  visualEventsClearedAt: null,
  view: location.hash.slice(1) || "overview",
  polling: null
};

const elements = {
  views: [...document.querySelectorAll(".view")],
  navItems: [...document.querySelectorAll(".nav-item")],
  sidebar: document.querySelector("#sidebar"),
  menu: document.querySelector("#menu-button"),
  mode: document.querySelector("#mode-pill"),
  globalStatus: document.querySelector("#global-status"),
  nodeContainer: document.querySelector("#node-container"),
  eventList: document.querySelector("#event-list"),
  activeBanner: document.querySelector("#active-test-banner"),
  activeLabel: document.querySelector("#active-test-label"),
  recordsBody: document.querySelector("#records-body"),
  recordsEmpty: document.querySelector("#records-empty"),
  search: document.querySelector("#record-search"),
  dialog: document.querySelector("#record-dialog"),
  form: document.querySelector("#record-form"),
  toastRegion: document.querySelector("#toast-region")
};

boot();

async function boot() {
  bindNavigation();
  bindActions();
  showView(state.view);
  await Promise.all([refreshOverview(), refreshRecords()]);
  state.polling = setInterval(refreshOverview, 2000);
}

function bindNavigation() {
  window.addEventListener("hashchange", () => showView(location.hash.slice(1) || "overview"));
  elements.menu.addEventListener("click", () => {
    const open = elements.sidebar.classList.toggle("open");
    elements.menu.setAttribute("aria-expanded", String(open));
  });
  elements.navItems.forEach((item) => item.addEventListener("click", () => closeMenu()));
}

function bindActions() {
  document.addEventListener("click", async (event) => {
    const testButton = event.target.closest("[data-run-test]");
    if (testButton) return runTest(testButton.dataset.runTest);
    const editButton = event.target.closest("[data-edit-record]");
    if (editButton) return openRecordDialog(editButton.dataset.editRecord);
    const deleteButton = event.target.closest("[data-delete-record]");
    if (deleteButton) return deleteRecord(deleteButton.dataset.deleteRecord);
  });
  document.querySelector("#recover-button").addEventListener("click", recoverAll);
  document.querySelector("#new-record-button").addEventListener("click", () => openRecordDialog());
  document.querySelector("#clear-visual-events").addEventListener("click", () => {
    state.visualEventsClearedAt = new Date().toISOString();
    renderEvents();
  });
  elements.search.addEventListener("input", renderRecords);
  elements.form.addEventListener("submit", saveRecord);
}

function showView(id) {
  const next = document.querySelector(`#${CSS.escape(id)}`) ? id : "overview";
  state.view = next;
  elements.views.forEach((view) => view.classList.toggle("active", view.id === next));
  elements.navItems.forEach((item) => item.classList.toggle("active", item.dataset.view === next));
  document.title = `${titleFor(next)} · Moodsitto Administración`;
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function refreshOverview() {
  try {
    state.overview = await api("/api/overview");
    renderOverview();
  } catch (error) {
    elements.globalStatus.textContent = "MONITOR DESCONECTADO";
    toast("Sin conexión", error.message, "error", 3500);
  }
}

function renderOverview() {
  const { nodes, metrics, activeTest, mode } = state.overview;
  const online = nodes.filter((node) => node.status === "online").length;
  const primary = nodes.find((node) => node.role === "PRIMARY");
  elements.mode.textContent = mode === "live" ? "MODO REAL" : "MODO DEMO";
  elements.globalStatus.textContent = primary && online >= 2 ? "SISTEMA DISPONIBLE" : online >= 2 ? "ELECCIÓN EN CURSO" : "SIN MAYORÍA";
  document.querySelector("#metric-availability").textContent = `${Number(metrics.availability).toFixed(metrics.availability === 100 ? 0 : 2)}%`;
  document.querySelector("#metric-nodes").textContent = `${online} / ${nodes.length}`;
  document.querySelector("#metric-writes").textContent = String(metrics.writes);
  document.querySelector("#metric-retries").textContent = String(metrics.retries);
  elements.nodeContainer.innerHTML = nodes.map(nodeTemplate).join("");
  elements.activeBanner.hidden = !activeTest;
  if (activeTest) elements.activeLabel.textContent = `${testLabel(activeTest.type)} · fase ${activeTest.phase}`;
  document.querySelectorAll("[data-run-test]").forEach((button) => { button.disabled = Boolean(activeTest); });
  renderEvents();
}

function nodeTemplate(node) {
  const statusClass = node.status === "online" ? "" : "offline";
  const primaryClass = node.role === "PRIMARY" ? "primary" : "";
  const connection = node.status === "online" ? "Tailscale conectado" : "Sin heartbeat";
  return `<article class="node-card ${statusClass} ${primaryClass}">
    <div class="node-top"><strong>${escapeHtml(node.name)}</strong><span class="role-badge">${escapeHtml(node.role)}</span></div>
    <p>${escapeHtml(node.host)} · ${escapeHtml(node.os || "node")}</p>
    <div class="node-meta"><span>${connection}</span><b>${node.status === "online" ? `${node.latencyMs ?? "—"} ms` : "OFFLINE"}</b></div>
  </article>`;
}

function renderEvents() {
  if (!state.overview) return;
  const threshold = state.visualEventsClearedAt ? new Date(state.visualEventsClearedAt).getTime() : 0;
  const events = state.overview.events.filter((item) => new Date(item.at).getTime() > threshold);
  elements.eventList.innerHTML = events.length
    ? events.map((item) => `<li class="${escapeHtml(item.level)}"><time>${formatTime(item.at)}</time><div class="event-copy"><strong>${escapeHtml(item.source)}</strong><span>${escapeHtml(item.message)}</span></div></li>`).join("")
    : `<li><time>—</time><div class="event-copy"><strong>Vista limpia</strong><span>Los nuevos eventos aparecerán aquí.</span></div></li>`;
}

async function runTest(type) {
  if (type === "quorum-loss" && !window.confirm("Esta prueba real detendrá dos nodos y bloqueará temporalmente las escrituras. ¿Continuar?")) return;
  try {
    setTestButtons(true);
    await api("/api/tests", { method: "POST", body: JSON.stringify({ type }) });
    toast("Prueba iniciada", testLabel(type), "success");
    await refreshOverview();
    location.hash = "overview";
  } catch (error) {
    toast("No se pudo iniciar", error.message, "error", 6000);
  } finally {
    setTestButtons(Boolean(state.overview?.activeTest));
  }
}

async function recoverAll() {
  try {
    await api("/api/recover", { method: "POST" });
    toast("Recuperación enviada", "Todos los servicios están volviendo a su estado seguro.", "success");
    await refreshOverview();
  } catch (error) {
    toast("Recuperación fallida", error.message, "error", 6000);
  }
}

async function refreshRecords() {
  try {
    state.records = await api("/api/records");
    renderRecords();
  } catch (error) {
    toast("CRUD no disponible", error.message, "error", 5000);
  }
}

function renderRecords() {
  const query = elements.search.value.trim().toLocaleLowerCase("es");
  const filtered = state.records.filter((record) => [record.patient, record.mood, record.note].some((value) => String(value || "").toLocaleLowerCase("es").includes(query)));
  document.querySelector("#record-count").textContent = String(state.records.length);
  elements.recordsEmpty.hidden = filtered.length > 0;
  elements.recordsBody.innerHTML = filtered.map((record) => `<tr>
    <td><strong>${escapeHtml(record.patient)}</strong></td>
    <td><span class="mood-pill">${escapeHtml(record.mood)}</span></td>
    <td><span class="score-bar"><b>${Number(record.score)}</b><i style="--score:${Number(record.score) * 10}%"></i></span></td>
    <td>${escapeHtml(record.note || "Sin nota")}</td>
    <td>${formatDate(record.createdAt)}</td>
    <td><div class="row-actions"><button data-edit-record="${record.id}" aria-label="Editar ${escapeHtml(record.patient)}">✎</button><button data-delete-record="${record.id}" aria-label="Eliminar ${escapeHtml(record.patient)}">×</button></div></td>
  </tr>`).join("");
}

function openRecordDialog(id) {
  const record = id ? state.records.find((item) => item.id === id) : null;
  document.querySelector("#dialog-title").textContent = record ? "Editar registro" : "Nuevo registro";
  document.querySelector("#record-id").value = record?.id || "";
  document.querySelector("#patient").value = record?.patient || "";
  document.querySelector("#mood").value = record?.mood || "";
  document.querySelector("#score").value = record?.score || 7;
  document.querySelector("#note").value = record?.note || "";
  elements.dialog.showModal();
  requestAnimationFrame(() => document.querySelector("#patient").focus());
}

async function saveRecord(event) {
  event.preventDefault();
  if (!elements.form.reportValidity()) return;
  const id = document.querySelector("#record-id").value;
  const payload = {
    patient: document.querySelector("#patient").value,
    mood: document.querySelector("#mood").value,
    score: Number(document.querySelector("#score").value),
    note: document.querySelector("#note").value
  };
  try {
    await api(id ? `/api/records/${id}` : "/api/records", { method: id ? "PATCH" : "POST", body: JSON.stringify(payload) });
    elements.dialog.close();
    toast(id ? "Registro actualizado" : "Registro creado", "MongoDB confirmó la escritura por mayoría.", "success");
    await Promise.all([refreshRecords(), refreshOverview()]);
  } catch (error) {
    toast("No se pudo guardar", error.message, "error", 6000);
  }
}

async function deleteRecord(id) {
  const record = state.records.find((item) => item.id === id);
  if (!record || !window.confirm(`¿Eliminar ${record.patient}? La operación se confirmará por mayoría.`)) return;
  try {
    await api(`/api/records/${id}`, { method: "DELETE" });
    toast("Registro eliminado", "DELETE confirmado por el replica set.", "success");
    await Promise.all([refreshRecords(), refreshOverview()]);
  } catch (error) {
    toast("No se pudo eliminar", error.message, "error", 6000);
  }
}

async function api(url, options = {}) {
  const response = await fetch(url, { headers: { "content-type": "application/json", ...(options.headers || {}) }, ...options });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.error || `HTTP ${response.status}`);
  }
  return response.status === 204 ? null : response.json();
}

function toast(title, message, type = "success", duration = 3800) {
  const node = document.createElement("div");
  node.className = `toast ${type}`;
  node.innerHTML = `<strong>${escapeHtml(title)}</strong><span>${escapeHtml(message)}</span>`;
  elements.toastRegion.append(node);
  setTimeout(() => node.remove(), duration);
}

function setTestButtons(disabled) { document.querySelectorAll("[data-run-test]").forEach((button) => { button.disabled = disabled; }); }
function closeMenu() { elements.sidebar.classList.remove("open"); elements.menu.setAttribute("aria-expanded", "false"); }
function formatTime(value) { return new Intl.DateTimeFormat("es-MX", { hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false }).format(new Date(value)); }
function formatDate(value) { return new Intl.DateTimeFormat("es-MX", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(value)); }
function titleFor(id) { return ({ overview: "Resumen", tests: "Pruebas", data: "CRUD", architecture: "Configuración" })[id] || "Resumen"; }
function testLabel(type) { return ({ "secondary-down": "Caída controlada de secundario", "primary-failover": "Failover del primario", "write-retry": "Escritura durante elección", "quorum-loss": "Pérdida de quorum" })[type] || type; }
function escapeHtml(value) { return String(value ?? "").replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character]); }
