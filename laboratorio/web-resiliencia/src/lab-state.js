const nowIso = () => new Date().toISOString();

export function createLabState(nodes) {
  return {
    nodes: nodes.map((node) => ({
      ...node,
      status: "unknown",
      role: "UNKNOWN",
      latencyMs: null,
      agentAvailable: false,
      lastSeen: null
    })),
    events: [event("Monitor", "Supervision real iniciada", "info")],
    activeTest: null,
    writes: 0,
    retries: 0,
    startedAt: Date.now()
  };
}

export function event(source, message, level = "info", meta = {}) {
  return { id: crypto.randomUUID(), at: nowIso(), source, message, level, ...meta };
}

export function addEvent(state, source, message, level = "info", meta = {}) {
  const duplicate = state.events[0]?.source === source && state.events[0]?.message === message;
  if (duplicate) return;
  state.events.unshift(event(source, message, level, meta));
  state.events = state.events.slice(0, 80);
}

export function publicSnapshot(state) {
  const online = state.nodes.filter((node) => node.status === "online").length;
  return {
    mode: "live",
    nodes: state.nodes,
    events: state.events.slice(0, 30),
    activeTest: state.activeTest,
    metrics: {
      availability: state.nodes.length ? Math.round((online / state.nodes.length) * 10000) / 100 : 0,
      writes: state.writes,
      retries: state.retries,
      uptimeSeconds: Math.floor((Date.now() - state.startedAt) / 1000)
    }
  };
}
