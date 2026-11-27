/* Otorga a APIcore acceso únicamente a su colección. La contraseña viene del entorno. */
const password = process.env.APICORE_MONGO_PASSWORD;
if (!password) throw new Error("Falta la contraseña de la cuenta de APIcore");
const base = db.getSiblingDB("moodsitto");
const coleccion = "historial_emociones_apicore";
if (!base.getCollectionNames().includes(coleccion)) throw new Error("Primero prepara el historial");
const role = "historial_apicore";
const user = "apicore_emociones";
if (base.getUser(user)) throw new Error("La cuenta ya existe. Usa un procedimiento de rotación si necesitas cambiarla");
const privilegios = [{
  resource: {db: "moodsitto", collection: coleccion},
  actions: ["find", "insert", "update"]
}];
if (!base.getRole(role)) base.createRole({role, roles: [], privileges: privilegios});
else base.updateRole(role, {roles: [], privileges: privilegios});
base.createUser({user, pwd: password, roles: [{role, db: "moodsitto"}]}, {w: "majority"});
print("Cuenta de historial lista");
