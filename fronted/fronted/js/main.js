// calendario y recordatorios de moodsitto
// elementos del dashboard
const dias = document.querySelectorAll(".dia");
const listaRecordatorios = document.querySelector(".recordatorios");
const formRecordatorio = document.getElementById("form-recordatorio");
const mensajeVacio = document.querySelector(".sin-recordatorios");

// los datos se conservan solo durante esta sesion del navegador
const claveRecordatorios = "moodsitto_recordatorios_temporales";
let recordatorios = [];

// recupera los recordatorios temporales si el navegador los permite
try {
    const guardados = JSON.parse(sessionStorage.getItem(claveRecordatorios) || "[]");
    if (Array.isArray(guardados)) {
        recordatorios = guardados.filter(r =>
            r && typeof r.id === "string" && typeof r.nombre === "string" &&
            leerFecha(r.inicio) && leerFecha(r.fin) && r.fin >= r.inicio &&
            /^([01]\d|2[0-3]):[0-5]\d$/.test(r.hora || "") &&
            ["una", "diaria", "semanal"].includes(r.repeticion)
        );
    }
} catch (error) {
    recordatorios = [];
}

// formato de fecha
function obtenerFecha(fecha) {
    const año = fecha.getFullYear();
    const mes = String(fecha.getMonth() + 1).padStart(2, "0");
    const dia = String(fecha.getDate()).padStart(2, "0");

    return `${año}-${mes}-${dia}`;
}

// convierte una fecha escrita a una fecha del calendario
function leerFecha(valor) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(valor || "")) return null;
    const [año, mes, dia] = valor.split("-").map(Number);
    const fecha = new Date(año, mes - 1, dia, 12);
    return obtenerFecha(fecha) === valor ? fecha : null;
}

// formato de hora
function mostrarHora(hora) {
    const [h, m] = hora.split(":").map(Number);
    const periodo = h < 12 ? "a. m." : "p. m.";
    const hora12 = h % 12 || 12;

    return `${hora12}:${String(m).padStart(2, "0")} ${periodo}`;
}

// guarda los cambios sin conectarse a la base de datos
function guardarRecordatorios() {
    try {
        sessionStorage.setItem(claveRecordatorios, JSON.stringify(recordatorios));
        return true;
    } catch (error) {
        alert("No se pudieron conservar los datos de esta sesión. Se perderán al actualizar la página.");
        return false;
    }
}

// revisa si un recordatorio corresponde a la fecha seleccionada
function correspondeAlDia(r, fecha) {
    if (!fecha || fecha < r.inicio || fecha > (r.fin || r.inicio)) return false;
    if (r.repeticion === "una") return fecha === r.inicio;
    if (r.repeticion === "diaria") return true;
    if (r.repeticion === "semanal") {
        const dia = leerFecha(fecha);
        if (!dia) return false;
        const numeroDia = dia.getDay() || 7;
        return Array.isArray(r.diasSemana) && r.diasSemana.includes(numeroDia);
    }
    return false;
}

// crea un recordatorio con sus botones
function crearRecordatorio(r, fecha) {
    // crear nuevo recordatorio
    const nuevo = document.createElement("div");
    nuevo.className = r.tipo === "cita" ? "recordatorio cita" : "recordatorio";
    nuevo.dataset.id = r.id;

    // asociar al dia seleccionado
    nuevo.dataset.fecha = fecha;

    // agregar icono si es cita
    const contenidoNombre = r.tipo === "cita"
        ? `<span class="texto-con-icono">
               <img src="img/icono-cita.svg" alt="" class="icono-cita-img">
               <span class="nombre-nuevo"></span>
           </span>`
        : `<span class="nombre-nuevo"></span>`;

    // coloca los iconos dentro de los botones
    nuevo.innerHTML = `
        ${contenidoNombre}
        <span class="hora-nueva"></span>
        <div class="acciones-recordatorio">
            <button type="button" class="completar"
                    aria-label="marcar como realizado" aria-pressed="false">
                <img src="img/icono-completar.png" alt="">
            </button>
            <button type="button" class="descartar"
                    aria-label="eliminar recordatorio">
                <img src="img/icono-eliminar.png" alt="">
            </button>
        </div>
    `;

    // colocar nombre y hora
    nuevo.querySelector(".nombre-nuevo").textContent =
        r.nombre + (r.dosis ? ` · ${r.dosis}` : "");
    nuevo.querySelector(".hora-nueva").textContent = mostrarHora(r.hora);

    const realizado = Array.isArray(r.completados) && r.completados.includes(fecha);
    nuevo.classList.toggle("completado", realizado);
    nuevo.querySelector(".completar").setAttribute("aria-pressed", String(realizado));
    return nuevo;
}

// mostrar recordatorios del dia
function mostrarRecordatorios() {
    if (!listaRecordatorios) return;
    const seleccionado = document.querySelector(".dia.seleccionado");
    if (!seleccionado) return;

    // borra los elementos mostrados para actualizar la lista
    listaRecordatorios.querySelectorAll(".recordatorio").forEach(r => r.remove());
    const fecha = seleccionado.dataset.fecha;
    const delDia = recordatorios
        .filter(r => correspondeAlDia(r, fecha))
        .sort((a, b) => a.hora.localeCompare(b.hora));

    // mostrar en la lista
    delDia.forEach(r => listaRecordatorios.insertBefore(
        crearRecordatorio(r, fecha), mensajeVacio
    ));

    if (mensajeVacio) mensajeVacio.hidden = delDia.length > 0;
}

// actualizar iconos de citas
function actualizarCitas() {
    if (!listaRecordatorios) return;
    dias.forEach(dia => {
        const tieneCita = recordatorios.some(r =>
            r.tipo === "cita" && correspondeAlDia(r, dia.dataset.fecha)
        );
        dia.classList.toggle("con-cita", tieneCita);
    });
}

// calendario semanal
let lunesActual;
let fechaSeleccionada = obtenerFecha(new Date());

// obtiene el lunes correspondiente a una fecha
function obtenerLunes(fecha) {
    const lunes = new Date(fecha);
    lunes.setHours(12, 0, 0, 0);
    lunes.setDate(lunes.getDate() - (lunes.getDay() + 6) % 7);
    return lunes;
}

// actualiza los numeros al cambiar de semana
function actualizarSemana() {
    if (!dias.length) return;
    dias.forEach((dia, i) => {
        const fecha = new Date(lunesActual);
        fecha.setDate(lunesActual.getDate() + i);
        dia.querySelector("strong").textContent = fecha.getDate();
        dia.dataset.fecha = obtenerFecha(fecha);

        // seleccionar el dia actual
        const activo = dia.dataset.fecha === fechaSeleccionada;
        dia.classList.toggle("seleccionado", activo);
        dia.setAttribute("aria-pressed", String(activo));
    });

    const fin = new Date(lunesActual);
    fin.setDate(fin.getDate() + 6);
    const textoFecha = fecha => fecha.toLocaleDateString("es-MX", {
        day: "numeric", month: "short"
    });
    const rangoSemana = document.getElementById("rango-semana");
    if (rangoSemana) rangoSemana.textContent =
        `${textoFecha(lunesActual)} al ${textoFecha(fin)}`;

    mostrarRecordatorios();
    actualizarCitas();
    const fechaInicio = document.getElementById("fecha-inicio");
    if (fechaInicio) {
        fechaInicio.value = fechaSeleccionada;
        actualizarOpciones();
    }
}

if (dias.length > 0) {
    lunesActual = obtenerLunes(new Date());
    dias.forEach(dia => {
        // cambiar de dia
        function seleccionarDia() {
            fechaSeleccionada = dia.dataset.fecha;
            actualizarSemana();
        }
        dia.addEventListener("click", seleccionarDia);
        dia.addEventListener("keydown", (evento) => {
            if (evento.key === "Enter" || evento.key === " ") {
                evento.preventDefault();
                seleccionarDia();
            }
        });
    });

    // los ejemplos se quitaron para mostrar solo los datos registrados
    actualizarSemana();

    document.getElementById("semana-anterior")?.addEventListener("click", () => {
        lunesActual.setDate(lunesActual.getDate() - 7);
        fechaSeleccionada = obtenerFecha(lunesActual);
        actualizarSemana();
    });
    document.getElementById("semana-siguiente")?.addEventListener("click", () => {
        lunesActual.setDate(lunesActual.getDate() + 7);
        fechaSeleccionada = obtenerFecha(lunesActual);
        actualizarSemana();
    });
}

// botones de recordatorios
if (listaRecordatorios) {
    listaRecordatorios.addEventListener("click", (evento) => {
        const boton = evento.target.closest("button");
        if (!boton) return;
        const recordatorio = boton.closest(".recordatorio");
        if (!recordatorio) return;
        const registro = recordatorios.find(r => r.id === recordatorio.dataset.id);
        if (!registro) return;

        // marcar como realizado
        if (boton.classList.contains("completar")) {
            const fecha = recordatorio.dataset.fecha;
            registro.completados = Array.isArray(registro.completados)
                ? registro.completados : [];
            if (registro.completados.includes(fecha)) {
                registro.completados = registro.completados.filter(d => d !== fecha);
            } else {
                registro.completados.push(fecha);
            }
            const realizado = registro.completados.includes(fecha);
            recordatorio.classList.toggle("completado", realizado);
            boton.setAttribute("aria-pressed", String(realizado));
            guardarRecordatorios();
        }

        // eliminar recordatorio
        if (boton.classList.contains("descartar")) {
            // al eliminar una serie tambien se borran los otros dias
            if (registro.repeticion !== "una") {
                const aceptar = confirm(
                    `¿Eliminar "${registro.nombre}" de todos los días programados?`
                );
                if (!aceptar) return;
            }
            recordatorios = recordatorios.filter(r => r.id !== registro.id);
            guardarRecordatorios();
            mostrarRecordatorios();
            actualizarCitas();
        }
    });
}

// muestra las opciones segun el tipo de recordatorio
function actualizarOpciones() {
    if (!formRecordatorio) return;
    const tipo = document.getElementById("tipo-recordatorio").value;
    const repeticion = document.getElementById("repeticion-recordatorio")?.value || "una";
    const campoDosis = document.getElementById("campo-dosis");
    const campoFin = document.getElementById("campo-fecha-fin");
    const campoDias = document.getElementById("dias-repeticion");
    const fechaFin = document.getElementById("fecha-fin");
    const fechaInicio = document.getElementById("fecha-inicio");

    if (campoDosis) campoDosis.hidden = tipo !== "medicamento";
    if (campoFin) campoFin.hidden = repeticion === "una";
    if (campoDias) {
        campoDias.hidden = repeticion !== "semanal";
        campoDias.disabled = repeticion !== "semanal";
    }
    if (fechaFin) {
        fechaFin.required = repeticion !== "una";
        fechaFin.disabled = repeticion === "una";
        fechaFin.min = fechaInicio?.value || "";
    }
    const dosis = document.getElementById("dosis-recordatorio");
    if (dosis) dosis.disabled = tipo !== "medicamento";
}

// agregar recordatorios
if (formRecordatorio && listaRecordatorios) {
    const tipoRecordatorio = document.getElementById("tipo-recordatorio");
    const repeticionRecordatorio = document.getElementById("repeticion-recordatorio");
    const fechaInicio = document.getElementById("fecha-inicio");
    tipoRecordatorio.addEventListener("change", actualizarOpciones);
    repeticionRecordatorio?.addEventListener("change", actualizarOpciones);
    fechaInicio?.addEventListener("change", actualizarOpciones);
    actualizarOpciones();

    formRecordatorio.addEventListener("submit", (evento) => {
        evento.preventDefault();
        const tipo = tipoRecordatorio.value;
        const nombre = document.getElementById("nombre-recordatorio").value.trim();
        const hora = document.getElementById("hora-recordatorio").value;
        const seleccionado = document.querySelector(".dia.seleccionado");
        const inicio = fechaInicio?.value || seleccionado?.dataset.fecha;
        const repeticion = repeticionRecordatorio?.value || "una";
        const fin = repeticion === "una" ? inicio : document.getElementById("fecha-fin")?.value;
        const dosis = tipo === "medicamento"
            ? (document.getElementById("dosis-recordatorio")?.value.trim() || "") : "";
        const diasSemana = Array.from(document.querySelectorAll(
            '#dias-repeticion input[type="checkbox"]:checked'
        )).map(c => Number(c.value));
        const mensaje = document.getElementById("mensaje-recordatorio");
        function avisar(texto) {
            if (mensaje) mensaje.textContent = texto;
            else alert(texto);
        }

        if (!nombre || !hora || !seleccionado || !leerFecha(inicio) || !leerFecha(fin)) {
            avisar("Completa el nombre, la hora y las fechas.");
            return;
        }
        if (fin < inicio) {
            avisar("La fecha final debe ser igual o posterior a la inicial.");
            return;
        }
        if (repeticion === "semanal" && diasSemana.length === 0) {
            avisar("Selecciona al menos un día de la semana.");
            return;
        }

        // crear nuevo recordatorio
        const nuevo = {
            id: `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
            tipo, nombre, hora, dosis, inicio, fin, repeticion,
            diasSemana, completados: []
        };
        // busca el primer dia en que corresponde este recordatorio
        let primeraFecha = inicio;
        if (repeticion === "semanal") {
            let fecha = leerFecha(inicio);
            primeraFecha = "";
            for (let i = 0; i < 7 && obtenerFecha(fecha) <= fin; i++) {
                if (correspondeAlDia(nuevo, obtenerFecha(fecha))) {
                    primeraFecha = obtenerFecha(fecha);
                    break;
                }
                fecha.setDate(fecha.getDate() + 1);
            }
            if (!primeraFecha) {
                avisar("No hay ningún día seleccionado dentro de ese periodo.");
                return;
            }
        }

        recordatorios.push(nuevo);
        const guardado = guardarRecordatorios();

        // se muestran los datos nuevos en la fecha elegida
        lunesActual = obtenerLunes(leerFecha(primeraFecha));
        fechaSeleccionada = primeraFecha;
        actualizarSemana();
        if (mensaje) mensaje.textContent = guardado
            ? "Recordatorio agregado en esta sesión."
            : "Recordatorio agregado solo en esta página.";

        // limpiar formulario sin ocultarlo
        formRecordatorio.reset();
        if (fechaInicio) fechaInicio.value = fechaSeleccionada;
        actualizarOpciones();
    });
}
