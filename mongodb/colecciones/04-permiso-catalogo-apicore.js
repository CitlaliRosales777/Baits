// Permite leer el catálogo con el usuario actual de APIcore, sin cambiar su contraseña.
const resultado = db.getSiblingDB("moodsitto").runCommand({
  grantPrivilegesToRole: "historial_apicore",
  privileges: [{ resource: { db: "moodsitto", collection: "catalogo_emociones" }, actions: ["find"] }],
  writeConcern: { w: "majority", wtimeout: 5000 }
});
if (!resultado.ok || resultado.writeConcernError) throw new Error("No se confirmó el permiso del catálogo");
print("Lectura del catálogo habilitada para APIcore");
