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

        await conBotonOcupado(formularioRegistro, "Creando cuenta...", async () => {
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
            datos.Name,
            datos.PaternalSurname,
            datos.MaternalSurname
        ].filter(Boolean).join(" "),
        "perfil-correo": datos.Email || "",
        "perfil-telefono": datos.Phone || "",
        "perfil-nacimiento": datos.BirthDate
            ? String(datos.BirthDate).slice(0, 10)
            : ""
    };

    for (const id in campos) {
        const campo = document.getElementById(id);
        if (campo) campo.value = campos[id];
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
