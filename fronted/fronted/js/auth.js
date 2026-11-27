/* formularios y sesion de moodsitto */
const paginaActual = window.location.pathname.split("/").pop() || "index.html";
const paginasPrivadas = ["dashboard.html", "perfil.html", "trackingmazz0o.html"];
const paginasDeAcceso = ["login.html", "registro.html"];

/* muestra mensajes en los formularios */
function mostrarMensaje(elemento, texto, esError = false) {
    if (!elemento) return;

    elemento.textContent = texto;
    elemento.classList.toggle("error", esError);
}

/* evita enviar un formulario dos veces */
async function conBotonOcupado(formulario, textoOcupado, tarea) {
    const boton = formulario.querySelector('button[type="submit"]');
    if (!boton) return;

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

/* protege las paginas del usuario: sin sesion se manda al login */
if (paginasPrivadas.includes(paginaActual) && (!sesion.token() || !sesion.usuario())) {
    sesion.borrar();
    window.location.replace("login.html");
}

/* si ya hay sesion, no tiene sentido ver el login ni el registro */
if (paginasDeAcceso.includes(paginaActual) && sesion.token() && sesion.usuario()) {
    window.location.replace("dashboard.html");
}

/* iniciar sesion */
const formularioLogin = document.getElementById("login-form");

if (formularioLogin) {
    const mensaje = document.getElementById("login-mensaje");

    formularioLogin.addEventListener("submit", async (evento) => {
        evento.preventDefault();
        mostrarMensaje(mensaje, "");

        const correo = formularioLogin.elements.namedItem("mail").value.trim();
        const contrasena = formularioLogin.elements.namedItem("passw").value;

        await conBotonOcupado(formularioLogin, "Ingresando...", async () => {
            try {
                await iniciarSesion(correo, contrasena);
                window.location.assign("dashboard.html");
            } catch (error) {
                mostrarMensaje(mensaje, error.message, true);
            }
        });
    });
}

/* registrar nuevo usuario */
const formularioRegistro = document.getElementById("registro-form");

if (formularioRegistro) {
    const mensaje = document.getElementById("registro-mensaje");

    formularioRegistro.addEventListener("submit", async (evento) => {
        evento.preventDefault();
        mostrarMensaje(mensaje, "");

        const f = formularioRegistro.elements;

        /* los nombres de los campos son los de la tabla users */
        const datos = {
            name: f.namedItem("name").value.trim(),
            lastname1: f.namedItem("lastname1").value.trim(),
            lastname2: f.namedItem("lastname2").value.trim(),
            date_b: f.namedItem("date_b").value,
            phone: f.namedItem("phone").value.trim(),
            emer_phone: f.namedItem("emer_phone").value.trim(),
            mail: f.namedItem("mail").value.trim(),
            passw: f.namedItem("passw").value
        };

        /* quita los campos opcionales vacios */
        Object.keys(datos).forEach((campo) => {
            if (datos[campo] === "") delete datos[campo];
        });

        await conBotonOcupado(formularioRegistro, "Creando cuenta...", async () => {
            try {
                await api("POST", "/users", datos);
                await iniciarSesion(datos.mail, datos.passw);
                window.location.assign("dashboard.html");
            } catch (error) {
                mostrarMensaje(mensaje, error.message, true);
            }
        });
    });
}

/* actualiza el menu cuando hay sesion */
const menu = document.querySelector(".encabezado .menu-principal");
const usuario = sesion.usuario();

if (menu && sesion.token() && usuario) {
    menu.querySelectorAll('a[href="login.html"], a[href="registro.html"]')
        .forEach(enlace => enlace.remove());

    if (paginaActual === "index.html") {
        const entrar = document.createElement("a");
        entrar.href = "dashboard.html";
        entrar.className = "menu-enlace destacado";
        entrar.textContent = "Mi espacio";
        menu.appendChild(entrar);
    }

    /* boton de cerrar sesion */
    const salir = document.createElement("a");
    salir.href = "index.html";
    salir.className = "menu-enlace";
    salir.textContent = "Cerrar sesión";

    salir.addEventListener("click", async (evento) => {
        evento.preventDefault();

        try {
            await cerrarSesion();
        } catch (error) {
            /* la sesion local se borra aunque falle el servidor */
        }

        sessionStorage.removeItem("moodsitto_recordatorios_temporales");
        window.location.assign("index.html");
    });

    menu.appendChild(salir);
}

/* muestra los datos del usuario en perfil */
function llenarPerfil(datos) {
    if (!datos) return;

    const campos = {
        "perfil-nombre": [
            datos.name,
            datos.lastname1,
            datos.lastname2
        ].filter(Boolean).join(" "),
        "perfil-correo": datos.mail || "",
        "perfil-telefono": datos.phone || "",
        "perfil-nacimiento": datos.date_b
            ? String(datos.date_b).slice(0, 10)
            : ""
    };

    for (const id in campos) {
        const campo = document.getElementById(id);
        if (campo) campo.value = campos[id];
    }
}

llenarPerfil(usuario);

/* comprueba que la sesion siga activa */
if (paginasPrivadas.includes(paginaActual) && sesion.token() && usuario) {
    (async () => {
        try {
            const perfil = await api("GET", "/users/" + usuario.id_user);

            if (perfil && perfil.data) {
                sesion.guardar(sesion.token(), perfil.data);
                llenarPerfil(perfil.data);
            }
        } catch (error) {
            if (error.status === 401 || !sesion.token()) {
                sesion.borrar();
                sessionStorage.removeItem("moodsitto_recordatorios_temporales");
                window.location.replace("login.html");
            } else {
                const aviso = document.getElementById("mensaje-conexion");
                mostrarMensaje(aviso, error.message, true);
            }
        }
    })();
}
