/* moodsitto - funciones iniciales */
const formularios = [
    { id: "login-form", mensaje: "login-mensaje" },
    { id: "registro-form", mensaje: "registro-mensaje" }
];
formularios.forEach(({ id, mensaje }) => {
    const formulario = document.getElementById(id);
    if (!formulario) return;

    formulario.addEventListener("submit", (evento) => {
        evento.preventDefault();

        const cajaMensaje = document.getElementById(mensaje);

        if (cajaMensaje) {
            cajaMensaje.textContent =
                "Esta pantalla es una demostración. " +
                "La conexión estará disponible cuando " +
                "el equipo integre el backend.";
        }
    });
});
// elementos del dashboard
const dias = document.querySelectorAll(".dia");
const listaRecordatorios = document.querySelector(".recordatorios");
const botonAgregar = document.querySelector(".agregar-recordatorio");
const formRecordatorio = document.getElementById("form-recordatorio");
const mensajeVacio = document.querySelector(".sin-recordatorios");
// formato de fecha
function obtenerFecha(fecha) {
    const año = fecha.getFullYear();
    const mes = String(fecha.getMonth() + 1).padStart(2, "0");
    const dia = String(fecha.getDate()).padStart(2, "0");

    return `${año}-${mes}-${dia}`;
}
// formato de hora
function mostrarHora(hora) {
    const [h, m] = hora.split(":").map(Number);
    const periodo = h < 12 ? "a. m." : "p. m.";
    const hora12 = h % 12 || 12;

    return `${hora12}:${String(m).padStart(2, "0")} ${periodo}`;
}
// mostrar recordatorios del dia
function mostrarRecordatorios() {
    if (!listaRecordatorios) return;
    const seleccionado = document.querySelector(".dia.seleccionado");
    if (!seleccionado) return;
    let cantidad = 0;
    listaRecordatorios.querySelectorAll(".recordatorio").forEach(r => {
        const coincide = r.dataset.fecha === seleccionado.dataset.fecha;

        r.hidden = !coincide;

        if (coincide) {
            cantidad++;
        }
    });
    if (mensajeVacio) {
        mensajeVacio.hidden = cantidad > 0;
    }
}
// actualizar iconos de citas
function actualizarCitas() {
    if (!listaRecordatorios) return;
    const citas = listaRecordatorios.querySelectorAll(".recordatorio.cita");
    dias.forEach(dia => {
        const tieneCita = Array.from(citas).some(cita =>
            cita.dataset.fecha === dia.dataset.fecha
        );
        dia.classList.toggle("con-cita", tieneCita);
    });
}
// calendario semanal
if (dias.length > 0) {
    const hoy = new Date();
    const lunes = new Date(hoy);
    lunes.setHours(12, 0, 0, 0);
    lunes.setDate(hoy.getDate() - (hoy.getDay() + 6) % 7);

    const fechaHoy = obtenerFecha(hoy);

    dias.forEach((dia, i) => {
        const fecha = new Date(lunes);
        fecha.setDate(lunes.getDate() + i);

        dia.querySelector("strong").textContent = fecha.getDate();
        dia.dataset.fecha = obtenerFecha(fecha);

        // seleccionar el dia actual
        dia.classList.toggle(
            "seleccionado",
            dia.dataset.fecha === fechaHoy
        );

        dia.setAttribute(
            "aria-pressed",
            dia.dataset.fecha === fechaHoy ? "true" : "false"
        );

        // cambiar de dia
        function seleccionarDia() {
            dias.forEach(d => {
                d.classList.remove("seleccionado");
                d.setAttribute("aria-pressed", "false");
            });

            dia.classList.add("seleccionado");
            dia.setAttribute("aria-pressed", "true");

            mostrarRecordatorios();
        }

        dia.addEventListener("click", seleccionarDia);

        dia.addEventListener("keydown", (evento) => {
            if (evento.key === "Enter" || evento.key === " ") {
                evento.preventDefault();
                seleccionarDia();
            }
        });
    });

    // recordatorios de ejemplo para hoy
    if (listaRecordatorios) {
        listaRecordatorios.querySelectorAll(".recordatorio").forEach(r => {
            r.dataset.fecha = fechaHoy;
        });
    }

    mostrarRecordatorios();
    actualizarCitas();
}

// botones de recordatorios
if (listaRecordatorios) {
    listaRecordatorios.addEventListener("click", (evento) => {
        const boton = evento.target.closest("button");
        if (!boton) return;

        const recordatorio = boton.closest(".recordatorio");
        if (!recordatorio) return;

        // marcar como realizado
        if (boton.classList.contains("completar")) {
            recordatorio.classList.toggle("completado");
        }

        // eliminar recordatorio
        if (boton.classList.contains("descartar")) {
            recordatorio.remove();

            mostrarRecordatorios();
            actualizarCitas();
        }
    });
}

// boton para ir al formulario
if (botonAgregar && formRecordatorio) {
    botonAgregar.addEventListener("click", () => {
        document.getElementById("nombre-recordatorio").focus();
    });
}

// agregar recordatorios
if (formRecordatorio && listaRecordatorios) {
    formRecordatorio.addEventListener("submit", (evento) => {
        evento.preventDefault();

        const tipo = document.getElementById("tipo-recordatorio").value;
        const nombre = document.getElementById("nombre-recordatorio").value.trim();
        const hora = document.getElementById("hora-recordatorio").value;
        const seleccionado = document.querySelector(".dia.seleccionado");

        if (!nombre || !hora || !seleccionado) return;

        // crear nuevo recordatorio
        const nuevo = document.createElement("div");

        nuevo.className = tipo === "cita"
            ? "recordatorio cita"
            : "recordatorio";

        // asociar al dia seleccionado
        nuevo.dataset.fecha = seleccionado.dataset.fecha;

        // agregar icono si es cita
        const contenidoNombre = tipo === "cita"
            ? `
                <span class="texto-con-icono">
                    <img src="img/icono-cita.svg"
                         alt=""
                         class="icono-cita-img">
                    <span class="nombre-nuevo"></span>
                </span>
              `
            : `<span class="nombre-nuevo"></span>`;

        nuevo.innerHTML = `
            ${contenidoNombre}

            <span class="hora-nueva"></span>

            <div class="acciones-recordatorio">
                <button type="button"
                        class="completar"
                        aria-label="marcar como realizado">✓</button>

                <button type="button"
                        class="descartar"
                        aria-label="eliminar recordatorio">×</button>
            </div>
        `;

        // colocar nombre y hora
        nuevo.querySelector(".nombre-nuevo").textContent = nombre;
        nuevo.querySelector(".hora-nueva").textContent = mostrarHora(hora);

        // mostrar en la lista
        listaRecordatorios.appendChild(nuevo);

        mostrarRecordatorios();
        actualizarCitas();

        // limpiar formulario sin ocultarlo
        formRecordatorio.reset();
    });
}
