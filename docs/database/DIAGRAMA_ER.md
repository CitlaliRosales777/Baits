# Diagrama entidad-relación

Refleja las migraciones V001–V003. `o{` indica cero o muchos; las FK opcionales se explican en el diccionario.

```mermaid
erDiagram
    LOCATION ||--o{ USERS : ubica
    LOCATION ||--o{ DOCTORS : ubica
    LOCATION ||--o{ CITAS_MEDICAS : sucede_en
    AREA ||--o{ DOCTORS : agrupa
    AREA ||--o{ DIAGNOSTICOS : clasifica
    AREA ||--o{ CITAS_MEDICAS : atiende
    ESPECIALIDAD ||--o{ DOCTOR_ESPECIALIDAD : clasifica
    DOCTORS ||--o{ DOCTOR_ESPECIALIDAD : posee
    ESTADOS_CLINICOS ||--o{ DIAGNOSTICOS : determina
    ESTADO ||--o{ DIAGNOSTICOS : controla
    ESTADO ||--o{ CITAS_MEDICAS : controla
    ESTADO ||--o{ MEDICAMENTO : controla
    ESTADO ||--o{ RECORDATORIOS : controla
    USERS ||--o{ DIAGNOSTICOS : recibe
    USERS ||--o{ CITAS_MEDICAS : agenda
    USERS ||--o{ MEDICAMENTO : registra
    USERS ||--o{ MEDICAMENTO_HORARIO : posee
    USERS ||--o{ TOMA_MEDICAMENTO : confirma
    USERS ||--o{ RECORDATORIOS : programa
    USERS ||--o{ TRACKEO_EMO : realiza
    DOCTORS ||--o{ DIAGNOSTICOS : emite
    DOCTORS ||--o{ CITAS_MEDICAS : atiende
    COMPUESTO ||--o{ MEDICAMENTO : compone
    DOSIS ||--o{ MEDICAMENTO : dosifica
    MEDICAMENTO ||--o{ MEDICAMENTO_HORARIO : programa
    HORARIOS ||--o{ MEDICAMENTO_HORARIO : define
    MEDICAMENTO_HORARIO ||--o{ TOMA_MEDICAMENTO : materializa
    HORARIOS ||--o{ RECORDATORIOS : pauta
    MEDICAMENTO_HORARIO o|--o{ RECORDATORIOS : origina
    CITAS_MEDICAS o|--o{ RECORDATORIOS : origina
    INTENSIDAD ||--o{ EMOCION_CENTRAL : clasifica
    INTENSIDAD ||--o{ EMOCION_MEDIA : clasifica
    INTENSIDAD ||--o{ EMOCION_ESPECIFICA : clasifica
    INTENSIDAD ||--o{ TRACKEO_EMO : registra
    EMOCION_CENTRAL ||--o{ EMOCION_MEDIA : contiene
    EMOCION_MEDIA ||--o{ EMOCION_ESPECIFICA : contiene
    EMOCION_CENTRAL ||--o{ EMOCION_CONJUNTO : integra
    EMOCION_MEDIA ||--o{ EMOCION_CONJUNTO : integra
    EMOCION_ESPECIFICA ||--o{ EMOCION_CONJUNTO : integra
    EMOCION_CONJUNTO ||--o{ TRACKEO_EMO : clasifica

    MEDICAMENTO_HORARIO {
        INT id_med_horario PK
        INT id_medicamento FK
        INT id_user FK
        INT id_horario FK
        DATE fecha_inicio
        DATE fecha_fin
        BOOLEAN activo
    }
    TOMA_MEDICAMENTO {
        BIGINT id_toma PK
        INT id_med_horario FK
        INT id_user FK
        DATETIME fecha_hora_programada UK
        DATETIME fecha_hora_efectiva
        VARCHAR estado_toma
    }
    DOCTOR_ESPECIALIDAD {
        INT id_doctor PK,FK
        INT id_especialidad PK,FK
        BOOLEAN es_principal
    }
    TRACKEO_EMO {
        INT id_trackeo PK
        INT id_user FK
        INT id_emo_conjunto FK
        INT id_intensidad FK
        DATE fecha
        TIME hora
    }
```

`schema_migrations` es técnica y se omite. `medicamento.id_horario` y `doctors.id_especialidad` se conservan temporalmente por compatibilidad; los modelos nuevos usan las tablas puente.
