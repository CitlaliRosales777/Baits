/* login y registro  */
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
            cajaMensaje.textContent = "Esta pantalla es una demostración. La conexión estará disponible cuando el equipo integre el backend.";
        }
    });
});

// elementos del dashboard
const dias = document.querySelectorAll(".dia");
const listaRecordatorios = document.querySelector(".recordatorios");
const formRecordatorio = document.getElementById("form-recordatorio");
const mensajeVacio = document.querySelector(".sin-recordatorios");
const claveRecordatorios = "moodsitto_recordatorios_temporales";

let recordatorios = [];
let lunesActual;
let fechaSeleccionada = obtenerFecha(new Date());

// convierte fechas y horas
function obtenerFecha(fecha) {
    const año = fecha.getFullYear();
    const mes = String(fecha.getMonth() + 1).padStart(2, "0");
    const dia = String(fecha.getDate()).padStart(2, "0");
    return `${año}-${mes}-${dia}`;
}

function leerFecha(valor) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(valor || "")) return null;

    const [año, mes, dia] = valor.split("-").map(Number);
    const fecha = new Date(año, mes - 1, dia, 12);

    return obtenerFecha(fecha) === valor ? fecha : null;
}

function mostrarHora(hora) {
    const [h, m] = hora.split(":").map(Number);
    const periodo = h < 12 ? "a. m." : "p. m.";

    return `${h % 12 || 12}:${String(m).padStart(2, "0")} ${periodo}`;
}

// recupera recordatorios de la sesion
if (listaRecordatorios) {
    try {
        const datos = JSON.parse(
            sessionStorage.getItem(claveRecordatorios) || "[]"
        );

        if (Array.isArray(datos)) {
            recordatorios = datos.filter(r =>
                r &&
                typeof r.id === "string" &&
                typeof r.nombre === "string" &&
                leerFecha(r.inicio) &&
                leerFecha(r.fin) &&
                r.fin >= r.inicio &&
                /^([01]\d|2[0-3]):[0-5]\d$/.test(r.hora || "") &&
                ["una", "diaria", "semanal"].includes(r.repeticion)
            );
        }
    } catch (error) {
        recordatorios = [];
    }
}

// guarda recordatorios en esta sesion
function guardarRecordatorios() {
    try {
        sessionStorage.setItem(
            claveRecordatorios,
            JSON.stringify(recordatorios)
        );
        return true;
    } catch (error) {
        alert("No se pudieron conservar los datos de esta sesión.");
        return false;
    }
}

// revisa los dias programados
function correspondeAlDia(r, fecha) {
    if (!fecha || fecha < r.inicio || fecha > r.fin) return false;

    if (r.repeticion === "una") {
        return fecha === r.inicio;
    }

    if (r.repeticion === "diaria") {
        return true;
    }

    if (r.repeticion === "semanal") {
        const dia = leerFecha(fecha);
        if (!dia) return false;

        return Array.isArray(r.diasSemana) &&
            r.diasSemana.includes(dia.getDay() || 7);
    }

    return false;
}

// crea cada recordatorio en pantalla
function crearRecordatorio(r, fecha) {
    const nuevo = document.createElement("div");

    nuevo.className = r.tipo === "cita"
        ? "recordatorio cita"
        : "recordatorio";

    nuevo.dataset.id = r.id;
    nuevo.dataset.fecha = fecha;

    const nombre = r.tipo === "cita"
        ? '<span class="texto-con-icono"><img src="img/icono-cita.svg" alt="" class="icono-cita-img"><span class="nombre-nuevo"></span></span>'
        : '<span class="nombre-nuevo"></span>';

    nuevo.innerHTML = `
        ${nombre}
        <span class="hora-nueva"></span>
        <div class="acciones-recordatorio">
            <button type="button" class="completar" aria-label="marcar como realizado" aria-pressed="false">
                <img src="img/icono-completar.png" alt="">
            </button>
            <button type="button" class="descartar" aria-label="eliminar recordatorio">
                <img src="img/icono-eliminar.png" alt="">
            </button>
        </div>
    `;

    nuevo.querySelector(".nombre-nuevo").textContent =
        r.nombre + (r.dosis ? ` · ${r.dosis}` : "");

    nuevo.querySelector(".hora-nueva").textContent = mostrarHora(r.hora);

    const realizado = Array.isArray(r.completados) &&
        r.completados.includes(fecha);

    nuevo.classList.toggle("completado", realizado);

    nuevo.querySelector(".completar").setAttribute(
        "aria-pressed",
        String(realizado)
    );

    return nuevo;
}

// muestra los recordatorios del dia elegido
function mostrarRecordatorios() {
    if (!listaRecordatorios) return;

    const seleccionado = document.querySelector(".dia.seleccionado");
    if (!seleccionado) return;

    listaRecordatorios.querySelectorAll(".recordatorio").forEach(r => {
        r.remove();
    });

    const fecha = seleccionado.dataset.fecha;

    const delDia = recordatorios
        .filter(r => correspondeAlDia(r, fecha))
        .sort((a, b) => a.hora.localeCompare(b.hora));

    delDia.forEach(r => {
        listaRecordatorios.insertBefore(
            crearRecordatorio(r, fecha),
            mensajeVacio
        );
    });

    if (mensajeVacio) {
        mensajeVacio.hidden = delDia.length > 0;
    }
}

// marca los dias que tienen citas
function actualizarCitas() {
    if (!listaRecordatorios) return;

    dias.forEach(dia => {
        const tieneCita = recordatorios.some(r =>
            r.tipo === "cita" &&
            correspondeAlDia(r, dia.dataset.fecha)
        );

        dia.classList.toggle("con-cita", tieneCita);
    });
}

// obtiene el lunes de la semana
function obtenerLunes(fecha) {
    const lunes = new Date(fecha);
    lunes.setHours(12, 0, 0, 0);

    lunes.setDate(
        lunes.getDate() - (lunes.getDay() + 6) % 7
    );

    return lunes;
}

// actualiza el calendario semanal
function actualizarSemana() {
    if (!dias.length) return;

    dias.forEach((dia, i) => {
        const fecha = new Date(lunesActual);
        fecha.setDate(lunesActual.getDate() + i);

        dia.querySelector("strong").textContent = fecha.getDate();
        dia.dataset.fecha = obtenerFecha(fecha);

        const activo = dia.dataset.fecha === fechaSeleccionada;

        dia.classList.toggle("seleccionado", activo);
        dia.setAttribute("aria-pressed", String(activo));
    });

    const fin = new Date(lunesActual);
    fin.setDate(fin.getDate() + 6);

    const textoFecha = fecha => fecha.toLocaleDateString("es-MX", {
        day: "numeric",
        month: "short"
    });

    const rango = document.getElementById("rango-semana");

    if (rango) {
        rango.textContent =
            `${textoFecha(lunesActual)} al ${textoFecha(fin)}`;
    }

    mostrarRecordatorios();
    actualizarCitas();

    const fechaInicio = document.getElementById("fecha-inicio");

    if (fechaInicio) {
        fechaInicio.value = fechaSeleccionada;
        actualizarOpciones();
    }
}

// permite elegir un dia o cambiar de semana
if (dias.length) {
    lunesActual = obtenerLunes(new Date());

    dias.forEach(dia => {
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

    actualizarSemana();

    document.getElementById("semana-anterior")?.addEventListener(
        "click",
        () => {
            lunesActual.setDate(lunesActual.getDate() - 7);
            fechaSeleccionada = obtenerFecha(lunesActual);
            actualizarSemana();
        }
    );

    document.getElementById("semana-siguiente")?.addEventListener(
        "click",
        () => {
            lunesActual.setDate(lunesActual.getDate() + 7);
            fechaSeleccionada = obtenerFecha(lunesActual);
            actualizarSemana();
        }
    );
}

// botones para completar o eliminar
if (listaRecordatorios) {
    listaRecordatorios.addEventListener("click", (evento) => {
        const boton = evento.target.closest("button");
        if (!boton) return;

        const elemento = boton.closest(".recordatorio");
        if (!elemento) return;

        const registro = recordatorios.find(r =>
            r.id === elemento.dataset.id
        );

        if (!registro) return;

        // marcar como realizado
        if (boton.classList.contains("completar")) {
            const fecha = elemento.dataset.fecha;

            registro.completados = Array.isArray(registro.completados)
                ? registro.completados
                : [];

            if (registro.completados.includes(fecha)) {
                registro.completados = registro.completados.filter(
                    d => d !== fecha
                );
            } else {
                registro.completados.push(fecha);
            }

            const realizado = registro.completados.includes(fecha);

            elemento.classList.toggle("completado", realizado);

            boton.setAttribute(
                "aria-pressed",
                String(realizado)
            );

            guardarRecordatorios();
        }

        // eliminar recordatorio
        if (boton.classList.contains("descartar")) {
            const texto = registro.repeticion === "una"
                ? `¿Eliminar "${registro.nombre}"?`
                : `¿Eliminar "${registro.nombre}" de todos los días programados?`;

            if (!confirm(texto)) return;

            recordatorios = recordatorios.filter(
                r => r.id !== registro.id
            );

            guardarRecordatorios();
            mostrarRecordatorios();
            actualizarCitas();
        }
    });
}

// muestra campos segun el tipo y repeticion
function actualizarOpciones() {
    if (!formRecordatorio) return;

    const tipo = document.getElementById("tipo-recordatorio").value;
    const repeticion = document.getElementById("repeticion-recordatorio").value;

    const campoDosis = document.getElementById("campo-dosis");
    const campoFin = document.getElementById("campo-fecha-fin");
    const campoDias = document.getElementById("dias-repeticion");
    const fechaFin = document.getElementById("fecha-fin");
    const fechaInicio = document.getElementById("fecha-inicio");
    const dosis = document.getElementById("dosis-recordatorio");

    if (campoDosis) {
        campoDosis.hidden = tipo !== "medicamento";
    }

    if (campoFin) {
        campoFin.hidden = repeticion === "una";
    }

    if (campoDias) {
        campoDias.hidden = repeticion !== "semanal";
        campoDias.disabled = repeticion !== "semanal";
    }

    if (fechaFin) {
        fechaFin.required = repeticion !== "una";
        fechaFin.disabled = repeticion === "una";
        fechaFin.min = fechaInicio?.value || "";

        if (fechaFin.value && fechaFin.value < fechaFin.min) {
            fechaFin.value = fechaFin.min;
        }
    }

    if (dosis) {
        dosis.disabled = tipo !== "medicamento";
    }
}

// agrega un recordatorio al calendario
if (formRecordatorio && listaRecordatorios) {
    const tipoRecordatorio =
        document.getElementById("tipo-recordatorio");

    const repeticionRecordatorio =
        document.getElementById("repeticion-recordatorio");

    const fechaInicio = document.getElementById("fecha-inicio");

    tipoRecordatorio.addEventListener("change", actualizarOpciones);
    repeticionRecordatorio.addEventListener("change", actualizarOpciones);
    fechaInicio.addEventListener("change", actualizarOpciones);

    actualizarOpciones();

    formRecordatorio.addEventListener("submit", (evento) => {
        evento.preventDefault();

        const tipo = tipoRecordatorio.value;
        const nombre = document.getElementById("nombre-recordatorio").value.trim();
        const hora = document.getElementById("hora-recordatorio").value;

        const seleccionado = document.querySelector(".dia.seleccionado");
        const inicio = fechaInicio.value || seleccionado?.dataset.fecha;
        const repeticion = repeticionRecordatorio.value;

        const fin = repeticion === "una"
            ? inicio
            : document.getElementById("fecha-fin").value;

        const dosis = tipo === "medicamento"
            ? document.getElementById("dosis-recordatorio").value.trim()
            : "";

        const diasSemana = Array.from(
            document.querySelectorAll(
                '#dias-repeticion input[type="checkbox"]:checked'
            )
        ).map(c => Number(c.value));

        const mensaje = document.getElementById("mensaje-recordatorio");

        function avisar(texto) {
            if (mensaje) {
                mensaje.textContent = texto;
            } else {
                alert(texto);
            }
        }

        // revisa que los datos sean validos
        if (!nombre || !hora || !seleccionado ||
            !leerFecha(inicio) || !leerFecha(fin)) {
            avisar("Completa el nombre, la hora y las fechas.");
            return;
        }

        if (fin < inicio) {
            avisar("La fecha final debe ser igual o posterior a la inicial.");
            return;
        }

        if (repeticion === "semanal" && !diasSemana.length) {
            avisar("Selecciona al menos un día de la semana.");
            return;
        }

        // crea el nuevo recordatorio
        const nuevo = {
            id: `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
            tipo,
            nombre,
            hora,
            dosis,
            inicio,
            fin,
            repeticion,
            diasSemana,
            completados: []
        };

        // busca el primer dia de la repeticion
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

        // guarda y actualiza el calendario
        recordatorios.push(nuevo);
        const guardado = guardarRecordatorios();

        lunesActual = obtenerLunes(leerFecha(primeraFecha));
        fechaSeleccionada = primeraFecha;
        actualizarSemana();

        formRecordatorio.reset();
        fechaInicio.value = fechaSeleccionada;
        actualizarOpciones();

        avisar(guardado
            ? "Recordatorio agregado en esta sesión."
            : "Recordatorio agregado solo en esta página."
        );
    });
}
