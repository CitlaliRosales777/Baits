/* moodsitto - funciones iniciales */
const formularios = [
    {
        id: "login-form",
        mensaje: "login-mensaje"
    },
    {
        id: "registro-form",
        mensaje: "registro-mensaje"
    }
];
formularios.forEach(({ id, mensaje }) => {
    const formulario = document.getElementById(id);
    if (!formulario) return;
    formulario.addEventListener("submit", function(evento) {
        evento.preventDefault();
        document.getElementById(mensaje).textContent =
            "Esta pantalla es una demostración. " +
            "La conexión estará disponible cuando " +
            "el equipo integre el backend.";
    });
});

// seleccionar dia del calendario
const dias = document.querySelectorAll(".dia");

dias.forEach(dia => {
    dia.addEventListener("click", () => {
        dias.forEach(d => d.classList.remove("seleccionado"));
        dia.classList.add("seleccionado");
    });
});

// fechas de la semana actual
if (dias.length > 0) {
    const hoy = new Date();
    const lunes = new Date(hoy);

    lunes.setDate(hoy.getDate() - (hoy.getDay() + 6) % 7);

    dias.forEach((dia, i) => {
        const fecha = new Date(lunes);
        fecha.setDate(lunes.getDate() + i);

        dia.querySelector("strong").textContent = fecha.getDate();
    });
}
