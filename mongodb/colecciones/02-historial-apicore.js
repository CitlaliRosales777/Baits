/* Prepara el historial del tablero. La identidad de APIcore se guarda aparte de la del backend Moodsitto. */
const destino = db.getSiblingDB("moodsitto");
const nombre = "historial_emociones_apicore";
const validator = {
  $jsonSchema: {
    bsonType: "object",
    required: ["apicore_user_id", "registro_id", "creado_at", "grupo"],
    properties: {
      apicore_user_id: { bsonType: ["int", "long"], minimum: 1 },
      registro_id: { bsonType: "string", minLength: 36, maxLength: 36 },
      creado_at: { bsonType: "date" },
      grupo: { bsonType: "array", minItems: 1, maxItems: 20 }
    }
  }
};
const resultado = destino.getCollectionNames().includes(nombre)
  ? destino.runCommand({collMod: nombre, validator})
  : destino.createCollection(nombre, {validator});
if (resultado.ok !== 1) throw new Error("No se pudo preparar la colección del historial");
destino.getCollection(nombre).createIndex({apicore_user_id: 1, registro_id: 1}, {unique: true, name: "registro_por_cuenta"});
destino.getCollection(nombre).createIndex({apicore_user_id: 1, creado_at: -1, registro_id: -1}, {name: "historial_por_fecha"});
