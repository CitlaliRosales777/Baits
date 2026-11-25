/* Moodsitto - Cliente de la API (apicore) */

// Dirección de la API. Cámbiala si la API corre en otro puerto o servidor.
const API_URL = "http://localhost:8000";

// Mensajes de la API traducidos para mostrarlos al usuario
const ERRORES = {
    "Invalid credentials": "Correo o contraseña incorrectos.",
    "Email already exists": "Ya existe una cuenta con ese correo.",
    "Username already exists": "Ese nombre de usuario ya está en uso.",
    "Email is not a valid email address": "El correo no es válido.",
    "Phone must contain only digits, spaces, +, - or ()":
        "El teléfono solo puede tener números, espacios, +, - o ().",
    "EmergencyPhone must contain only digits, spaces, +, - or ()":
        "El teléfono de emergencia solo puede tener números, espacios, +, - o ().",
    "BirthDate must be a date like 2026-01-31": "La fecha de nacimiento no es válida.",
    "Name must be 45 chars max": "El nombre no puede pasar de 45 caracteres.",
    "PaternalSurname must be 25 chars max": "El apellido paterno no puede pasar de 25 caracteres.",
    "MaternalSurname must be 25 chars max": "El apellido materno no puede pasar de 25 caracteres.",
    "Database unavailable": "La base de datos no está disponible. Intenta más tarde."
};

function traducirError(mensaje, status) {
    if (ERRORES[mensaje]) return ERRORES[mensaje];
    if (status === 429) return "Demasiados intentos. Espera 15 minutos e inténtalo de nuevo.";
    return mensaje || "Ocurrió un error inesperado.";
}

/**
 * Llama a la API y devuelve el JSON de la respuesta.
 * Lanza un Error con el mensaje ya traducido si la respuesta no es 2xx.
 */
async function api(metodo, ruta, datos) {
    const opciones = { method: metodo, headers: {} };
    const token = sesion.token();
    if (token) opciones.headers["Authorization"] = "Bearer " + token;
    if (datos !== undefined) {
        opciones.headers["Content-Type"] = "application/json";
        opciones.body = JSON.stringify(datos);
    }

    let respuesta;
    try {
        respuesta = await fetch(API_URL + ruta, opciones);
    } catch (error) {
        throw new Error("No se pudo conectar con el servidor. ¿Está encendida la API?");
    }

    const cuerpo = respuesta.status === 204 ? null : await respuesta.json().catch(() => null);
    if (!respuesta.ok) {
        throw new Error(traducirError(cuerpo && cuerpo.error, respuesta.status));
    }
    return cuerpo;
}

/* Sesión guardada en el navegador */
const sesion = {
    token() {
        return localStorage.getItem("moodsitto_token");
    },
    usuario() {
        try {
            return JSON.parse(localStorage.getItem("moodsitto_usuario"));
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

/* Lee el id de usuario (campo "sub") que viene dentro del token */
function idDelToken(token) {
    const parte = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(parte)).sub;
}

/* Inicia sesión, guarda el token y los datos del usuario */
async function iniciarSesion(correo, contrasena) {
    const login = await api("POST", "/auth/login", {
        Username: correo,
        Password: contrasena
    });
    const token = login.data.token;
    sesion.guardar(token, null);
    const perfil = await api("GET", "/users/" + idDelToken(token));
    sesion.guardar(token, perfil.data);
    return perfil.data;
}

async function cerrarSesion() {
    try {
        await api("POST", "/auth/logout");
    } finally {
        sesion.borrar();
    }
}
