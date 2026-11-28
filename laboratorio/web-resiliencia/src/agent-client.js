export async function invokeAgent(node, action, token) {
  if (!node.agentUrl) throw new Error(`El nodo ${node.name} no tiene agentUrl configurado`);
  const response = await fetch(`${node.agentUrl.replace(/\/$/, "")}/service/${action}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    signal: AbortSignal.timeout(7000)
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error || `Agente ${node.name}: HTTP ${response.status}`);
  return body;
}

export async function agentStatus(node, token) {
  if (!node.agentUrl) return { available: false, service: "unknown" };
  try {
    const response = await fetch(`${node.agentUrl.replace(/\/$/, "")}/status`, {
      headers: { authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(2500)
    });
    if (!response.ok) return { available: false, service: "unknown" };
    return { available: true, ...(await response.json()) };
  } catch {
    return { available: false, service: "unreachable" };
  }
}
