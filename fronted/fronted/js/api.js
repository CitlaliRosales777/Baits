/* conexion con la api de moodsitto */
// El puerto 8000 pertenece a APIcore. Este cliente habla con el backend de Moodsitto.
const API_URL = "http://localhost:8001";

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
// Guarda esta sesión por separado para evitar reutilizar el token de la otra API.
const claveSesion = "moodsitto_backend";
const sesion = {
    token() {
        return localStorage.getItem(claveSesion + "_token");
    },

    usuario() {
        try {
            return JSON.parse(localStorage.getItem(claveSesion + "_usuario") || "null");
        } catch (error) {
            return null;
        }
    },

    guardar(token, usuario) {
        localStorage.setItem(claveSesion + "_token", token);
        localStorage.setItem(claveSesion + "_usuario", JSON.stringify(usuario));
    },

    borrar() {
        localStorage.removeItem(claveSesion + "_token");
        localStorage.removeItem(claveSesion + "_usuario");
    }
};

// Separa los datos del navegador por servicio y por cuenta.
function claveLocalCuenta(nombre) {
    const id = sesion.usuario()?.id_user;
    return sesion.token() && id ? "backend:" + id + ":" + nombre : null;
}

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
        throw new Error("No se pudo conectar con el backend de Moodsitto en localhost:8001.");
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
