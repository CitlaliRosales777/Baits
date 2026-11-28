/* formularios y sesion de moodsitto */
const paginaActual = window.location.pathname.split("/").pop() || "index.html";
const paginasPrivadas = ["dashboard.html", "perfil.html", "trackingmazz0o.html"];

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

/* protege las paginas del usuario */
if (paginasPrivadas.includes(paginaActual) && !sesion.token()) {
    window.location.replace("login.html");
}

/* iniciar sesion */
const formularioLogin = document.getElementById("login-form");

if (formularioLogin) {
    const mensaje = document.getElementById("login-mensaje");

    formularioLogin.addEventListener("submit", async (evento) => {
        evento.preventDefault();
        mostrarMensaje(mensaje, "");

        const identificador = formularioLogin.elements.namedItem("mail").value.trim();
        const contrasena = formularioLogin.elements.namedItem("passw").value;

        await conBotonOcupado(formularioLogin, "Ingresando…", async () => {
            try {
                await iniciarSesion(identificador, contrasena);
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

        /* datos que necesita apicore */
        const datos = {
            Name: f.namedItem("name").value.trim(),
            PaternalSurname: f.namedItem("lastname1").value.trim(),
            MaternalSurname: f.namedItem("lastname2").value.trim(),
            BirthDate: f.namedItem("date_b").value,
            Phone: f.namedItem("phone").value.trim(),
            EmergencyPhone: f.namedItem("emer_phone").value.trim(),
            Email: f.namedItem("mail").value.trim(),
            Password: f.namedItem("passw").value,
            UserStatus: "Active"
        };

        /* quita los campos opcionales vacios */
        Object.keys(datos).forEach((campo) => {
            if (datos[campo] === "") delete datos[campo];
        });

        await conBotonOcupado(formularioRegistro, "Creando cuenta…", async () => {
            try {
                await api("POST", "/users", datos);
                await iniciarSesion(datos.Email, datos.Password);
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
const conSesion = Boolean(sesion.token() && usuario);

document.querySelectorAll("[data-sesion]").forEach(elemento => {
    elemento.hidden = (elemento.dataset.sesion === "activa") !== conSesion;
});

document.querySelector(".pie-arriba")?.addEventListener("click", evento => {
    evento.preventDefault();
    document.getElementById("arriba").focus({ preventScroll: true });
    window.scrollTo(0, 0);
});

if (conSesion && ["login.html", "registro.html"].includes(paginaActual)) {
    window.location.replace("dashboard.html");
}

if (conSesion && menu && paginaActual === "index.html") {
    menu.querySelectorAll('a[href="login.html"], a[href="registro.html"]').forEach(enlace => enlace.remove());
    const entrar = document.createElement("a");
    entrar.href = "dashboard.html";
    entrar.className = "menu-enlace destacado";
    entrar.dataset.icono = "perfil";
    entrar.textContent = "Mi espacio";
    menu.appendChild(entrar);
}

if (conSesion && menu) {
    const botonSalir = document.createElement("button");
    botonSalir.type = "button";
    botonSalir.className = "menu-enlace";
    botonSalir.dataset.icono = "salir";
    botonSalir.textContent = "Cerrar sesión";
    botonSalir.addEventListener("click", async () => {
        botonSalir.disabled = true;
        botonSalir.textContent = "Cerrando sesión…";
        try {
            await cerrarSesion();
        } catch (error) {
            /* la sesion local se borra aunque falle el servidor */
        }

        sessionStorage.removeItem("moodsitto_recordatorios_temporales");
        window.location.assign("index.html");
    });
    menu.appendChild(botonSalir);
}

/* muestra los datos del usuario en perfil */
function llenarPerfil(datos) {
    if (!datos || !document.getElementById("perfil-nombre")) return;

    const nombres = [datos.Name, datos.PaternalSurname, datos.MaternalSurname].filter(Boolean);
    const iniciales = document.getElementById("perfil-iniciales");
    if (nombres.length) {
        iniciales.removeAttribute("data-icono");
        iniciales.textContent = nombres.slice(0, 2).map(parte => Array.from(parte.trim())[0]).join("").toUpperCase();
    }
    const nacimiento = new Date(String(datos.BirthDate).slice(0, 10) + "T12:00:00");

    const campos = {
        "perfil-nombre": nombres.join(" ") || "Mi cuenta",
        "perfil-usuario": datos.Username || "",
        "perfil-correo": datos.Email || "",
        "perfil-telefono": datos.Phone || "",
        "perfil-nacimiento": Number.isFinite(nacimiento.getTime())
            ? nacimiento.toLocaleDateString("es-MX", { dateStyle: "long" })
            : ""
    };

    for (const id in campos) {
        const campo = document.getElementById(id);
        if (campo) campo.textContent = campos[id] || "Sin datos";
    }
}

llenarPerfil(usuario);

/* comprueba que la sesion siga activa */
if (paginasPrivadas.includes(paginaActual) && sesion.token()) {
    (async () => {
        try {
            const id = idDelToken(sesion.token());
            const perfil = await api("GET", "/users/" + encodeURIComponent(id));

            if (perfil?.data) {
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
