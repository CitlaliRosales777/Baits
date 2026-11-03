
/* Moodsitto - Funciones iniciales */
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
