// calendario y recordatorios de moodsitto
// elementos del dashboard
const dias = document.querySelectorAll(".dia");
const listaRecordatorios = document.querySelector(".recordatorios");
const formRecordatorio = document.getElementById("form-recordatorio");
const mensajeVacio = document.querySelector(".sin-recordatorios");

const rutaRecordatorios = "/tablero/recordatorios";
const estadoRecordatorios = document.getElementById("estado-recordatorios");
const resumenSemana = document.getElementById("resumen-semana");
const fechaRecordatorios = document.getElementById("fecha-recordatorios");
const pendienteHoy = document.getElementById("pendiente-hoy");
const formatoDia = new Intl.DateTimeFormat("es-MX", { weekday: "long", day: "numeric", month: "long" });
let recordatorios = [];
let recordatoriosCargados = false;
let cargaRecordatorios;
let guardandoRecordatorio = false;

function esInterrupcionDeRecordatorios(error) {
    return error.status === 0 || (error.status >= 500 && error.status < 600);
}

// Una sola consulta a la vez. Los fallos transitorios se recuperan sin tocar el formulario.
function cargarRecordatorios(reconectando = false) {
    if (!listaRecordatorios || !sesion.token() || cargaRecordatorios) return;
    estadoRecordatorios.textContent = reconectando ? "Reconectando con APIcore…" : "Cargando recordatorios…";
    cargaRecordatorios = (async () => {
        for (let espera = 1000; sesion.token(); espera = Math.min(espera * 2, 4000)) {
            try {
                const respuesta = await api("GET", rutaRecordatorios, undefined, AbortSignal.timeout(7000));
                if (!Array.isArray(respuesta?.data)) throw new Error("No se pudo leer la lista de recordatorios.");
                recordatorios = respuesta.data;
                recordatoriosCargados = true;
                mostrarRecordatorios();
                actualizarCitas();
                estadoRecordatorios.textContent = "";
                return;
            } catch (error) {
                if (!esInterrupcionDeRecordatorios(error)) {
                    estadoRecordatorios.textContent = error.message;
                    return;
                }
                if (estadoRecordatorios.textContent !== "Reconectando con APIcore…") {
                    estadoRecordatorios.textContent = "Reconectando con APIcore…";
                }
                await new Promise(resolve => setTimeout(resolve, espera));
            }
        }
    })().finally(() => { cargaRecordatorios = undefined; });
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

// Pide confirmación a APIcore antes de mostrar el cambio como guardado.
async function guardarCambio(metodo, registro, aplicar) {
    if (guardandoRecordatorio) return false;
    if (!recordatoriosCargados) {
        cargarRecordatorios();
        return false;
    }
    guardandoRecordatorio = true;
    try {
        await api(metodo, rutaRecordatorios + "/" + registro.id, metodo === "PUT" ? registro : undefined, AbortSignal.timeout(7000));
        aplicar();
        estadoRecordatorios.textContent = "";
        return true;
    } catch (error) {
        if (esInterrupcionDeRecordatorios(error)) {
            recordatoriosCargados = false;
            mostrarRecordatorios();
            cargarRecordatorios(true);
        } else {
            estadoRecordatorios.textContent = error.message;
        }
        return false;
    } finally {
        guardandoRecordatorio = false;
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
    if (fechaRecordatorios) {
        fechaRecordatorios.dateTime = fecha;
        fechaRecordatorios.textContent = formatoDia.format(leerFecha(fecha));
    }
    const delDia = recordatoriosCargados ? recordatoriosDelDia(fecha) : [];

    // mostrar en la lista
    delDia.forEach(r => listaRecordatorios.insertBefore(
        crearRecordatorio(r, fecha), mensajeVacio
    ));

    if (mensajeVacio) mensajeVacio.hidden = !recordatoriosCargados || delDia.length > 0;
    actualizarResumenSemana();
    mostrarPendienteDeHoy();
}

function recordatoriosDelDia(fecha) {
    return recordatorios.filter(r => correspondeAlDia(r, fecha))
        .sort((a, b) => a.hora.localeCompare(b.hora));
}

function mostrarPendienteDeHoy() {
    if (!pendienteHoy) return;
    pendienteHoy.hidden = !recordatoriosCargados;
    if (!recordatoriosCargados) return;

    const fecha = obtenerFecha(new Date());
    const pendientes = recordatoriosDelDia(fecha).filter(r => !r.completados?.includes(fecha));
    const primero = pendientes[0];
    document.getElementById("titulo-pendiente-hoy").textContent = primero
        ? `Hoy · ${pendientes.length} ${pendientes.length === 1 ? "pendiente" : "pendientes"}`
        : "Hoy · sin pendientes";
    document.getElementById("detalle-pendiente-hoy").textContent = primero
        ? `${mostrarHora(primero.hora)} · ${primero.nombre}`
        : "";
}

function actualizarResumenSemana() {
    if (!resumenSemana) return;
    resumenSemana.hidden = !recordatoriosCargados;
    if (!recordatoriosCargados) return;
    let pendientes = 0;
    let completados = 0;
    dias.forEach(dia => {
        const fecha = dia.dataset.fecha;
        recordatorios.forEach(registro => {
            if (!correspondeAlDia(registro, fecha)) return;
            if (registro.completados?.includes(fecha)) completados++;
            else pendientes++;
        });
    });
    document.getElementById("semana-pendientes").textContent = pendientes;
    document.getElementById("semana-completados").textContent = completados;
    const avance = document.getElementById("avance-semana");
    const total = pendientes + completados;
    avance.hidden = total === 0;
    avance.max = total || 1;
    avance.value = completados;
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
        dia.setAttribute("aria-label", formatoDia.format(fecha));

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
    listaRecordatorios.addEventListener("click", async (evento) => {
        const boton = evento.target.closest("button");
        if (!boton) return;
        const recordatorio = boton.closest(".recordatorio");
        if (!recordatorio) return;
        const registro = recordatorios.find(r => r.id === recordatorio.dataset.id);
        if (!registro) return;

        // marcar como realizado
        if (boton.classList.contains("completar")) {
            const fecha = recordatorio.dataset.fecha;
            const completados = registro.completados.includes(fecha)
                ? registro.completados.filter(d => d !== fecha)
                : [...registro.completados, fecha];
            await guardarCambio("PUT", {...registro, completados}, () => {
                registro.completados = completados;
                mostrarRecordatorios();
                actualizarCitas();
            });
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
            await guardarCambio("DELETE", registro, () => {
                recordatorios = recordatorios.filter(r => r.id !== registro.id);
                mostrarRecordatorios();
                actualizarCitas();
            });
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
    const modal = document.getElementById("panel-recordatorio");
    const botonNuevo = document.getElementById("nuevo-recordatorio");
    const botonCancelar = document.getElementById("cancelar-recordatorio");
    const botonGuardar = document.getElementById("guardar-recordatorio");
    const mensaje = document.getElementById("mensaje-recordatorio");
    const tipoRecordatorio = document.getElementById("tipo-recordatorio");
    const repeticionRecordatorio = document.getElementById("repeticion-recordatorio");
    const fechaInicio = document.getElementById("fecha-inicio");
    tipoRecordatorio.addEventListener("change", actualizarOpciones);
    repeticionRecordatorio?.addEventListener("change", actualizarOpciones);
    fechaInicio?.addEventListener("change", actualizarOpciones);
    actualizarOpciones();

    botonNuevo.addEventListener("click", () => modal.showModal());
    botonCancelar.addEventListener("click", () => modal.close());
    modal.addEventListener("cancel", evento => {
        if (botonGuardar.disabled) evento.preventDefault();
    });
    modal.addEventListener("close", () => {
        formRecordatorio.reset();
        fechaInicio.value = fechaSeleccionada;
        mensaje.textContent = "";
        actualizarOpciones();
    });

    formRecordatorio.addEventListener("submit", async (evento) => {
        evento.preventDefault();
        if (botonGuardar.disabled) return;
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
        if (!nombre || !hora || !seleccionado || !leerFecha(inicio) || !leerFecha(fin)) {
            mensaje.textContent = "Completa el nombre, la hora y las fechas.";
            return;
        }
        if (fin < inicio) {
            mensaje.textContent = "La fecha final debe ser igual o posterior a la inicial.";
            return;
        }
        if (repeticion === "semanal" && diasSemana.length === 0) {
            mensaje.textContent = "Selecciona al menos un día de la semana.";
            return;
        }

        // Reutiliza el identificador al reenviar los mismos datos.
        const datos = {tipo, nombre, hora, dosis, inicio, fin, repeticion, diasSemana, completados: []};
        const huella = JSON.stringify(datos);
        if (formRecordatorio.dataset.pendiente !== huella) {
            formRecordatorio.dataset.pendiente = huella;
            formRecordatorio.dataset.idPendiente = crypto.randomUUID();
        }
        const nuevo = {
            id: formRecordatorio.dataset.idPendiente, ...datos
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
                mensaje.textContent = "No hay ningún día seleccionado dentro de ese periodo.";
                return;
            }
        }

        botonGuardar.disabled = botonCancelar.disabled = true;
        botonGuardar.textContent = "Guardando…";
        mensaje.textContent = "";
        const guardado = await guardarCambio("PUT", nuevo, () => {
            recordatorios = [...recordatorios.filter(r => r.id !== nuevo.id), nuevo];
        });
        botonGuardar.disabled = botonCancelar.disabled = false;
        botonGuardar.textContent = "Guardar recordatorio";
        if (!guardado) {
            mensaje.textContent = recordatoriosCargados
                ? estadoRecordatorios.textContent || "Espera a que termine el cambio en curso y vuelve a guardar."
                : "La agenda se está conectando. Vuelve a intentar en unos segundos.";
            botonGuardar.focus();
            return;
        }
        delete formRecordatorio.dataset.pendiente;
        delete formRecordatorio.dataset.idPendiente;

        // se muestran los datos nuevos en la fecha elegida
        lunesActual = obtenerLunes(leerFecha(primeraFecha));
        fechaSeleccionada = primeraFecha;
        actualizarSemana();
        modal.close();
        estadoRecordatorios.textContent = "Recordatorio guardado.";
    });
}

const fechaTablero = document.getElementById("fecha-tablero");
if (fechaTablero) {
    const hoy = new Date();
    fechaTablero.dateTime = obtenerFecha(hoy);
    fechaTablero.textContent = formatoDia.format(hoy);
    const nombre = sesion.usuario()?.Name?.trim();
    if (nombre) document.getElementById("saludo-tablero").textContent = `Hola, ${nombre}`;
}
cargarRecordatorios();

// Cada entrada del historial puede contener varias emociones del mismo registro.
async function cargarEmocionesRecientes() {
    const lista = document.getElementById("lista-emociones-tablero");
    if (!lista || !sesion.token()) return;
    const estado = document.getElementById("estado-emociones-tablero");
    estado.textContent = "Cargando emociones…";
    try {
        const { data } = await api("GET", "/tablero/emociones", undefined, AbortSignal.timeout(7000));
        if (!Array.isArray(data)) throw new Error("Formato de historial inválido.");
        const entradas = data.filter(entrada => entrada?.t &&
            Number.isFinite(new Date(entrada.t).getTime()) &&
            Array.isArray(entrada.group) && entrada.group.some(g => typeof g?.core === "string" && g.core.trim()));
        const recientes = entradas.sort((a, b) => new Date(b.t) - new Date(a.t)).slice(0, 3);
        const formatoFecha = new Intl.DateTimeFormat("es-MX", { dateStyle: "medium", timeStyle: "short" });
        const nombres = new Map([["Enojao", "Enojo"], ["Troste", "Tristeza"]]);

        for (const entrada of recientes) {
            const elemento = document.createElement("li");
            const tiempo = document.createElement("time");
            const fecha = new Date(entrada.t);
            tiempo.dateTime = fecha.toISOString();
            tiempo.textContent = formatoFecha.format(fecha);
            const emociones = document.createElement("strong");
            emociones.textContent = entrada.group
                .filter(g => typeof g?.core === "string" && g.core.trim())
                .map(({core}) => nombres.get(core) || core).join(" · ");
            elemento.append(tiempo, emociones);
            lista.append(elemento);
        }

        lista.hidden = recientes.length === 0;
        document.getElementById("enlace-historial-tablero").hidden = lista.hidden;
        estado.textContent = lista.hidden ? "Aquí aparecerán tus primeros registros." : "";
    } catch {
        estado.textContent = "No se pudieron cargar tus emociones.";
        document.getElementById("enlace-historial-tablero").hidden = false;
    }
}
cargarEmocionesRecientes();
