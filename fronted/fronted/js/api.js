/* conexion con la api de moodsitto */
// direccion de la api. cambiala cuando la api este publicada en internet.
const API_URL = "http://localhost:8000";

/* traduce los errores de la api para mostrarlos al usuario */
function traducirError(mensaje, estado) {
    // la api ya responde en español, asi que se muestra tal cual
    if (typeof mensaje === "string" && mensaje) return mensaje;
    if (estado === 401) return "Tu sesión venció. Inicia sesión de nuevo.";
    if (estado === 429) return "Demasiados intentos. Intenta más tarde.";
    if (estado >= 500) return "El servidor no está disponible.";
    return "Ocurrió un error inesperado.";
}

/* datos de la sesion (se guardan en el navegador) */
const sesion = {
    token() {
        return localStorage.getItem("moodsitto_token");
    },

    usuario() {
        try {
            return JSON.parse(localStorage.getItem("moodsitto_usuario") || "null");
        } catch (error) {
            return null;
        }
    },

    guardar(token, usuario) {
        localStorage.setItem("moodsitto_token", token);
        localStorage.setItem("moodsitto_usuario", JSON.stringify(usuario));
    },

    borrar() {
        localStorage.removeItem("moodsitto_token");
        localStorage.removeItem("moodsitto_usuario");
    }
};

/* envia una solicitud a la api y regresa el json */
async function api(metodo, ruta, datos) {
    const opciones = {
        method: metodo,
        headers: {}
    };

    const token = sesion.token();

    if (token) {
        opciones.headers["Authorization"] = "Bearer " + token;
    }

    if (datos !== undefined) {
        opciones.headers["Content-Type"] = "application/json";
        opciones.body = JSON.stringify(datos);
    }

    let respuesta;

    try {
        respuesta = await fetch(API_URL + ruta, opciones);
    } catch (error) {
        throw new Error("No se pudo conectar con el servidor. Revisa que la API esté encendida.");
    }

    const cuerpo = respuesta.status === 204
        ? null
        : await respuesta.json().catch(() => null);

    if (!respuesta.ok) {
        // token vencido o falso: se borra la sesion (menos en el login, donde 401 es clave incorrecta)
        if (respuesta.status === 401 && ruta !== "/auth/login") {
            sesion.borrar();
        }

        const error = new Error(traducirError(cuerpo && cuerpo.error, respuesta.status));
        error.status = respuesta.status;
        throw error;
    }

    return cuerpo;
}

/* inicia sesion y guarda el token y el perfil */
async function iniciarSesion(correo, contrasena) {
    const login = await api("POST", "/auth/login", {
        mail: correo,
        passw: contrasena
    });

    const token = login && login.data && login.data.token;
    const id = login && login.data && login.data.id_user;

    if (!token || !id) {
        throw new Error("El servidor no devolvió una sesión válida.");
    }

    try {
        // se guarda el token primero porque la siguiente solicitud lo necesita
        sesion.guardar(token, null);

        const perfil = await api("GET", "/users/" + id);

        if (!perfil || !perfil.data) {
            throw new Error("No se pudieron obtener tus datos.");
        }

        sesion.guardar(token, perfil.data);
        return perfil.data;
    } catch (error) {
        sesion.borrar();
        throw error;
    }
}

/* cierra la sesion */
async function cerrarSesion() {
    try {
        await api("POST", "/auth/logout");
    } finally {
        sesion.borrar();
    }
}
