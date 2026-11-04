-- Nodo SQL Server propuesto para la demostración multibase.
-- Ejecutar solo en una base de desarrollo creada por el administrador.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'moodsitto_clinical')
    EXEC(N'CREATE SCHEMA moodsitto_clinical');
GO

CREATE TABLE moodsitto_clinical.user_reference (
    maria_user_id       INT NOT NULL PRIMARY KEY,
    correlation_id     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    created_at          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_user_reference_correlation UNIQUE (correlation_id)
);
GO

CREATE TABLE moodsitto_clinical.clinical_note (
    clinical_note_id    BIGINT IDENTITY(1,1) PRIMARY KEY,
    maria_user_id       INT NOT NULL,
    professional_ref    NVARCHAR(100) NOT NULL,
    note_type           NVARCHAR(50) NOT NULL,
    note_summary        NVARCHAR(500) NULL,
    occurred_at         DATETIME2 NOT NULL,
    status              NVARCHAR(30) NOT NULL,
    created_at          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    row_version         ROWVERSION,
    CONSTRAINT fk_clinical_note_user_reference FOREIGN KEY (maria_user_id)
        REFERENCES moodsitto_clinical.user_reference(maria_user_id),
    CONSTRAINT chk_clinical_note_status CHECK (status IN (N'active', N'closed', N'cancelled'))
);
GO

CREATE INDEX idx_clinical_note_user_date
    ON moodsitto_clinical.clinical_note(maria_user_id, occurred_at DESC);
GO

-- No existe una FK entre motores. APIcore crea/verifica user_reference mediante
-- una operación idempotente antes de escribir la nota y registra fallos parciales.

