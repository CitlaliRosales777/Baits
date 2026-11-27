/* conexion con la api de moodsitto */
const API_URL = "http://localhost:8000";

/* mensajes de error */
const ERRORES = {
    "Invalid credentials": "Correo o contraseña incorrectos.",
    "Email already exists": "Ya existe una cuenta con ese correo.",
    "Username already exists": "Ese nombre de usuario ya está en uso.",
    "Email is not a valid email address": "El correo no es válido.",
    "Phone must contain only digits, spaces, +, - or ()": "El teléfono contiene caracteres no permitidos.",
    "EmergencyPhone must contain only digits, spaces, +, - or ()": "El teléfono de emergencia contiene caracteres no permitidos.",
    "BirthDate must be a date like 2026-01-31": "La fecha de nacimiento no es válida.",
    "Name must be 45 chars max": "El nombre no puede superar 45 caracteres.",
    "PaternalSurname must be 25 chars max": "El apellido paterno no puede superar 25 caracteres.",
    "MaternalSurname must be 25 chars max": "El apellido materno no puede superar 25 caracteres.",
    "Database unavailable": "La base de datos no está disponible."
};

/* traduce los mensajes de la api */
function traducirError(mensaje, estado) {
    if (ERRORES[mensaje]) return ERRORES[mensaje];
    if (estado === 401) return "Tu sesión venció o tus datos son incorrectos.";
    if (estado === 429) return "Demasiados intentos. Intenta más tarde.";
    if (estado >= 500) return "El servidor no está disponible.";
    return typeof mensaje === "string" ? mensaje : "Ocurrió un error inesperado.";
}

/* datos de la sesion */
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

/* envia solicitudes al servidor */
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
        throw new Error("No se pudo conectar con APIcore. Revisa que el servidor esté encendido.");
    }

    const cuerpo = respuesta.status === 204
        ? null
        : await respuesta.json().catch(() => null);

    if (!respuesta.ok) {
        if (respuesta.status === 401 && ruta !== "/auth/login") {
            sesion.borrar();
        }

        const error = new Error(traducirError(cuerpo?.error, respuesta.status));
        error.status = respuesta.status;
        throw error;
    }

    return cuerpo;
}

/* obtiene el id del usuario desde el token */
function idDelToken(token) {
    try {
        const parte = token.split(".")[1]
            .replace(/-/g, "+")
            .replace(/_/g, "/");

        const contenido = JSON.parse(
            atob(parte.padEnd(Math.ceil(parte.length / 4) * 4, "="))
        );

        if (!contenido.sub) {
            throw new Error("Token sin usuario");
        }

        return contenido.sub;
    } catch (error) {
        throw new Error("No se pudo leer la sesión.");
    }
}

/* inicia sesion y obtiene el perfil */
async function iniciarSesion(correo, contrasena) {
    const login = await api("POST", "/auth/login", {
        Username: correo,
        Password: contrasena
    });

    const token = login?.data?.token;

    if (!token) {
        throw new Error("El servidor no devolvió una sesión válida.");
    }

    try {
        sesion.guardar(token, null);

        const id = idDelToken(token);
        const perfil = await api("GET", "/users/" + encodeURIComponent(id));

        if (!perfil?.data) {
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
