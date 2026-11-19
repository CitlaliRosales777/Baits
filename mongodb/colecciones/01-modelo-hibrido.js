/* Ejecutar autenticado contra la base moodsitto. Idempotente. */
const target = db.getSiblingDB("moodsitto");

function ensureCollection(name, validator) {
  if (!target.getCollectionNames().includes(name)) {
    target.createCollection(name, { validator, validationLevel: "strict", validationAction: "error" });
  } else {
    target.runCommand({ collMod: name, validator, validationLevel: "strict", validationAction: "error" });
  }
}

ensureCollection("catalogo_emociones", {
  $jsonSchema: {
    bsonType: "object",
    required: ["codigo", "nombre", "nivel", "activo", "created_at", "updated_at"],
    properties: {
      codigo: { bsonType: "string", minLength: 1, maxLength: 80 },
      nombre: { bsonType: "string", minLength: 1, maxLength: 80 },
      descripcion: { bsonType: ["string", "null"], maxLength: 1000 },
      nivel: { enum: ["central", "media", "especifica"] },
      parent_codigo: { bsonType: ["string", "null"], maxLength: 80 },
      color: { bsonType: ["string", "null"], pattern: "^#[0-9A-Fa-f]{6}$" },
      activo: { bsonType: "bool" },
      created_at: { bsonType: "date" },
      updated_at: { bsonType: "date" }
    }
  }
});

ensureCollection("registros_emocionales", {
  $jsonSchema: {
    bsonType: "object",
    required: ["id_user", "emocion_codigo", "intensidad", "ocurrio_at", "idempotency_key", "created_at"],
    properties: {
      id_user: { bsonType: ["int", "long"], minimum: 1 },
      emocion_codigo: { bsonType: "string", minLength: 1, maxLength: 80 },
      intensidad: { bsonType: "int", minimum: 1, maximum: 10 },
      contexto: { bsonType: ["string", "null"], maxLength: 4000 },
      etiquetas: { bsonType: "array", maxItems: 20, items: { bsonType: "string", maxLength: 50 } },
      ocurrio_at: { bsonType: "date" },
      idempotency_key: { bsonType: "string", minLength: 16, maxLength: 80 },
      created_at: { bsonType: "date" },
      updated_at: { bsonType: ["date", "null"] }
    }
  }
});

ensureCollection("resumenes_emocionales", {
  $jsonSchema: {
    bsonType: "object",
    required: ["id_user", "periodo_inicio", "periodo_fin", "version", "metricas", "generated_at"],
    properties: {
      id_user: { bsonType: ["int", "long"], minimum: 1 },
      periodo_inicio: { bsonType: "date" },
      periodo_fin: { bsonType: "date" },
      version: { bsonType: "int", minimum: 1 },
      metricas: { bsonType: "object" },
      generated_at: { bsonType: "date" }
    }
  }
});

ensureCollection("auditoria_documental", {
  $jsonSchema: {
    bsonType: "object",
    required: ["accion", "recurso", "resultado", "correlacion_id", "created_at"],
    properties: {
      actor_id_user: { bsonType: ["int", "long", "null"], minimum: 1 },
      accion: { bsonType: "string", minLength: 1, maxLength: 80 },
      recurso: { bsonType: "string", minLength: 1, maxLength: 80 },
      recurso_id: { bsonType: ["string", "null"], maxLength: 100 },
      resultado: { enum: ["ok", "denegado", "error"] },
      correlacion_id: { bsonType: "string", minLength: 16, maxLength: 80 },
      metadata_segura: { bsonType: ["object", "null"] },
      created_at: { bsonType: "date" }
    }
  }
});

target.catalogo_emociones.createIndex({ codigo: 1 }, { unique: true, name: "uq_catalogo_codigo" });
target.catalogo_emociones.createIndex({ parent_codigo: 1, nivel: 1 }, { name: "idx_catalogo_parent_nivel" });
target.registros_emocionales.createIndex({ id_user: 1, ocurrio_at: -1 }, { name: "idx_registro_user_fecha" });
target.registros_emocionales.createIndex({ id_user: 1, idempotency_key: 1 }, { unique: true, name: "uq_registro_idempotencia" });
target.resumenes_emocionales.createIndex({ id_user: 1, periodo_inicio: 1, periodo_fin: 1, version: 1 }, { unique: true, name: "uq_resumen_periodo_version" });
target.auditoria_documental.createIndex({ actor_id_user: 1, created_at: -1 }, { name: "idx_auditoria_actor_fecha" });
target.auditoria_documental.createIndex({ recurso: 1, created_at: -1 }, { name: "idx_auditoria_recurso_fecha" });

printjson({ collections: target.getCollectionNames().sort(), ok: 1 });
