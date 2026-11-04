# Diagrama entidad-relación

El diagrama refleja `V002__create_relational_model.sql`. Las relaciones marcadas `o|` son opcionales en la tabla hija; las demás son obligatorias.

```mermaid
erDiagram
    LOCATION ||--o{ USERS : ubica
    LOCATION ||--o{ DOCTORS : ubica
    LOCATION ||--o{ CITAS_MEDICAS : sucede_en
    AREA ||--o{ DOCTORS : agrupa
    AREA ||--o{ DIAGNOSTICOS : clasifica
    AREA ||--o{ CITAS_MEDICAS : atiende
    ESPECIALIDAD ||--o{ DOCTORS : especializa
    ESTADOS_CLINICOS ||--o{ DIAGNOSTICOS : determina
    ESTADO ||--o{ DIAGNOSTICOS : estado
    ESTADO ||--o{ CITAS_MEDICAS : estado
    ESTADO ||--o{ MEDICAMENTO : estado
    ESTADO ||--o{ RECORDATORIOS : estado
    USERS ||--o{ DIAGNOSTICOS : recibe
    USERS ||--o{ CITAS_MEDICAS : agenda
    USERS ||--o{ MEDICAMENTO : registra
    USERS ||--o{ RECORDATORIOS : programa
    USERS ||--o{ TRACKEO_EMO : realiza
    DOCTORS ||--o{ DIAGNOSTICOS : emite
    DOCTORS ||--o{ CITAS_MEDICAS : atiende
    COMPUESTO ||--o{ MEDICAMENTO : compone
    DOSIS ||--o{ MEDICAMENTO : dosifica
    HORARIOS ||--o{ MEDICAMENTO : pauta
    HORARIOS ||--o{ RECORDATORIOS : pauta
    CITAS_MEDICAS o|--o{ RECORDATORIOS : origina
    INTENSIDAD ||--o{ EMOCION_CENTRAL : mide
    INTENSIDAD ||--o{ EMOCION_MEDIA : mide
    INTENSIDAD ||--o{ EMOCION_ESPECIFICA : mide
    EMOCION_CENTRAL ||--o{ EMOCION_MEDIA : contiene
    EMOCION_MEDIA ||--o{ EMOCION_ESPECIFICA : contiene
    EMOCION_CENTRAL ||--o{ EMOCION_CONJUNTO : referencia
    EMOCION_MEDIA ||--o{ EMOCION_CONJUNTO : referencia
    EMOCION_ESPECIFICA ||--o{ EMOCION_CONJUNTO : referencia
    EMOCION_CONJUNTO ||--o{ TRACKEO_EMO : clasifica

    USERS {
        INT id_user PK
        VARCHAR mail UK
        VARCHAR passw "hash"
        INT id_location FK "opcional"
    }
    DOCTORS {
        INT id_doctor PK
        VARCHAR cedula UK
        INT id_area FK
        INT id_especialidad FK
    }
    CITAS_MEDICAS {
        INT id_cita PK
        INT id_user FK
        INT id_doctor FK
        DATETIME fecha
        INT id_estado FK
    }
    DIAGNOSTICOS {
        INT id_diagnostico PK
        INT id_user FK
        INT id_doctor FK
        DATE fecha
        VARCHAR documento
    }
    MEDICAMENTO {
        INT id_medicamento PK
        INT id_user FK
        INT cantidad
        INT id_horario FK
    }
    RECORDATORIOS {
        INT id_recordatorio PK
        INT id_user FK
        INT id_cita FK "opcional"
        DATETIME fecha
    }
    TRACKEO_EMO {
        INT id_trackeo PK
        INT id_user FK
        INT id_emo_conjunto FK
        DATE fecha
        TIME hora
    }
```

La tabla técnica `schema_migrations` no forma parte del dominio y se omite del diagrama.

