/* Moodsitto - Formularios y sesión (usa js/api.js) */

function mostrarMensaje(elemento, texto, esError) {
    elemento.textContent = texto;
    elemento.classList.toggle("error", Boolean(esError));
}

/* Deshabilita el botón mientras se espera a la API */
async function conBotonOcupado(formulario, textoOcupado, tarea) {
    const boton = formulario.querySelector("button[type=submit]");
    const textoOriginal = boton.textContent;
    boton.disabled = true;
    boton.textContent = textoOcupado;
    try {
        await tarea();
    } finally {
        boton.disabled = false;
        boton.textContent = textoOriginal;
    }
}

/* Iniciar sesión */
const formularioLogin = document.getElementById("login-form");
if (formularioLogin) {
    const mensaje = document.getElementById("login-mensaje");
    formularioLogin.addEventListener("submit", (evento) => {
        evento.preventDefault();
        const correo = formularioLogin.elements.mail.value.trim();
        const contrasena = formularioLogin.elements.passw.value;
        conBotonOcupado(formularioLogin, "Ingresando...", async () => {
            try {
                await iniciarSesion(correo, contrasena);
                window.location.href = "index.html";
            } catch (error) {
                mostrarMensaje(mensaje, error.message, true);
            }
        });
    });
}

/* Registro */
const formularioRegistro = document.getElementById("registro-form");
if (formularioRegistro) {
    const mensaje = document.getElementById("registro-mensaje");
    formularioRegistro.addEventListener("submit", (evento) => {
        evento.preventDefault();
        const f = formularioRegistro.elements;
        // Nombres de los campos que espera la API (tabla users de apicore)
        const datos = {
            Name: f.name.value.trim(),
            PaternalSurname: f.lastname1.value.trim(),
            MaternalSurname: f.lastname2.value.trim(),
            BirthDate: f.date_b.value,
            Phone: f.phone.value.trim(),
            EmergencyPhone: f.emer_phone.value.trim(),
            Email: f.mail.value.trim(),
            Password: f.passw.value,
            UserStatus: "Active"
        };
        // Los campos opcionales vacíos no se envían
        Object.keys(datos).forEach((campo) => {
            if (datos[campo] === "") delete datos[campo];
        });

        conBotonOcupado(formularioRegistro, "Creando cuenta...", async () => {
            try {
                await api("POST", "/users", datos);
                await iniciarSesion(datos.Email, datos.Password);
                window.location.href = "index.html";
            } catch (error) {
                mostrarMensaje(mensaje, error.message, true);
            }
        });
    });
}

/* Menú: si hay sesión, muestra el nombre y "Cerrar sesión" */
const menu = document.querySelector(".encabezado nav");
const usuario = sesion.usuario();
if (menu && sesion.token() && usuario) {
    menu.querySelectorAll('a[href="login.html"], a[href="registro.html"]')
        .forEach((enlace) => enlace.remove());

    const saludo = document.createElement("span");
    saludo.className = "saludo";
    saludo.textContent = "Hola, " + usuario.Name;

    const salir = document.createElement("a");
    salir.href = "#";
    salir.textContent = "Cerrar sesión";
    salir.addEventListener("click", async (evento) => {
        evento.preventDefault();
        try {
            await cerrarSesion();
        } catch (error) {
            // El token ya no era válido: la sesión local ya se borró
        }
        window.location.href = "index.html";
    });

    menu.append(saludo, salir);
}
