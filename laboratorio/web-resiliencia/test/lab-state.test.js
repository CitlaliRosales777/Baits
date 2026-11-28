import test from "node:test";
import assert from "node:assert/strict";
import { addEvent, createLabState, publicSnapshot } from "../src/lab-state.js";

const nodes = [
  { id: "a", name: "node-a", host: "100.64.0.1", priority: 2 },
  { id: "b", name: "node-b", host: "100.64.0.2", priority: 1 },
  { id: "c", name: "node-c", host: "100.64.0.3", priority: 0 }
];

test("inicia sin inventar estados de los nodos", () => {
  const state = createLabState(nodes);
  assert.equal(state.nodes.every((node) => node.status === "unknown"), true);
  assert.equal(state.nodes.every((node) => node.role === "UNKNOWN"), true);
  assert.equal(publicSnapshot(state).mode, "live");
  assert.equal(publicSnapshot(state).metrics.availability, 0);
});

test("calcula disponibilidad solo con estados observados", () => {
  const state = createLabState(nodes);
  state.nodes[0].status = "online";
  state.nodes[1].status = "online";
  assert.equal(publicSnapshot(state).metrics.availability, 66.67);
});

test("evita duplicar el mismo evento consecutivo", () => {
  const state = createLabState(nodes);
  addEvent(state, "Monitor", "Sin conexion", "danger");
  addEvent(state, "Monitor", "Sin conexion", "danger");
  assert.equal(state.events.filter((item) => item.message === "Sin conexion").length, 1);
});
