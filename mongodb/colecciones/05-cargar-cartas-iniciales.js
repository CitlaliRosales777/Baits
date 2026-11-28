// Ejecutar con mongosh desde la raíz de Baits-db-manager y con acceso al catálogo.
const fs = require("node:fs");
const cartas = JSON.parse(fs.readFileSync("mongodb/colecciones/cartas-iniciales.json", "utf8"));
const ahora = new Date();
const catalogo = db.getSiblingDB("moodsitto").catalogo_emociones;
const resultado = catalogo.bulkWrite(cartas.map(carta => ({
  updateOne: {
    filter: { codigo: carta.codigo },
    update: { $setOnInsert: { ...carta, created_at: ahora, updated_at: ahora } },
    upsert: true
  }
})), { writeConcern: { w: "majority", wtimeout: 5000 } });
print(JSON.stringify({ cartasIniciales: cartas.length, agregadas: resultado.upsertedCount }));
