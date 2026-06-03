-- ================================================================
--  SGT — Sistema de Gestión de Tutorías
--  SQL Server (T-SQL)
--  Instituto Tecnológico de México Campus Culiacán
--  Equipo: Zepeda Alcaraz Francia Ximena - 22170859
--          Osuna Tirado Jose Carlos       - 22170759
--          Soto Cortez Jesus Eugenio      - 22170829
--
--  VERSIÓN 3 — Incluye todos los ajustes post-pruebas
--
--  INSTRUCCIONES:
--  1. Abre este archivo en SSMS
--  2. Presiona F5 para ejecutar
--  3. Todo se crea desde cero correctamente
--
--  Contraseña de todos los usuarios de prueba: password
-- ================================================================

USE master;
GO

-- Eliminar BD si existe y crear nueva
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SISTEMA_TUTORIAS')
BEGIN
    ALTER DATABASE SISTEMA_TUTORIAS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SISTEMA_TUTORIAS;
END;
GO

CREATE DATABASE SISTEMA_TUTORIAS;
GO

USE SISTEMA_TUTORIAS;
GO

-- ================================================================
-- BLOQUE 1: TABLAS BASE
-- ================================================================

CREATE TABLE TECNM (
    idTecnm            INT IDENTITY(1,1) PRIMARY KEY,
    claveInstitucional VARCHAR(50) NOT NULL
);
GO

CREATE TABLE ITCuliacan (
    idITC     INT IDENTITY(1,1) PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL,
    direccion VARCHAR(200),
    telefono  VARCHAR(20),
    idTecnm   INT NOT NULL REFERENCES TECNM(idTecnm)
);
GO

-- ================================================================
-- BLOQUE 2: USUARIO (tabla central)
-- ================================================================

CREATE TABLE Usuario (
    idUsuario    INT IDENTITY(1,1) PRIMARY KEY,
    nombre       NVARCHAR(150) NOT NULL,
    correoInst   NVARCHAR(150) NOT NULL UNIQUE,
    passwordHash NVARCHAR(255) NOT NULL DEFAULT 'CAMBIAR_AL_PRIMER_LOGIN',
    rol          NVARCHAR(60)  NOT NULL,
    estado       NVARCHAR(30)  NOT NULL DEFAULT 'Activo',
    numEmpleado  NVARCHAR(20)  NULL,
    numControl   NVARCHAR(20)  NULL,
    departamento NVARCHAR(100) NULL,
    carrera      NVARCHAR(100) NULL,
    created_at   DATETIME2     NOT NULL DEFAULT GETDATE(),
    updated_at   DATETIME2     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT chk_rol CHECK (rol IN (
        'Administrador','Coordinadora Institucional','Coordinadora Departamental',
        'Jefe Departamento','Director','Subdirector','Tutor','Tutorado'
    )),
    CONSTRAINT chk_estado_usuario CHECK (estado IN ('Activo','Inactivo','Suspendido'))
);
GO

CREATE UNIQUE INDEX uq_numEmpleado ON Usuario(numEmpleado) WHERE numEmpleado IS NOT NULL;
CREATE UNIQUE INDEX uq_numControl  ON Usuario(numControl)  WHERE numControl  IS NOT NULL;
GO

-- RF-USU-01 CA-01: valida dominio institucional
CREATE TRIGGER trg_ValidarCorreo
ON Usuario
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE correoInst NOT LIKE '%@culiacan.tecnm.mx'
          AND correoInst NOT LIKE '%@itculiacan.edu.mx'
    )
    BEGIN
        RAISERROR(N'El correo debe pertenecer al dominio institucional.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- ================================================================
-- BLOQUE 3: CATÁLOGO DE ROLES
-- ================================================================

CREATE TABLE Roles (
    idRol     INT IDENTITY(1,1) PRIMARY KEY,
    nombreRol NVARCHAR(60) UNIQUE NOT NULL
);
GO

INSERT INTO Roles(nombreRol) VALUES
('Administrador'),('Coordinadora Institucional'),('Coordinadora Departamental'),
('Jefe Departamento'),('Director'),('Subdirector'),('Tutor'),('Tutorado');
GO

CREATE TABLE UsuarioRol (
    idUsuarioRol INT IDENTITY(1,1) PRIMARY KEY,
    idUsuario    INT NOT NULL REFERENCES Usuario(idUsuario),
    idRol        INT NOT NULL REFERENCES Roles(idRol),
    CONSTRAINT uq_usuario_rol UNIQUE(idUsuario, idRol)
);
GO

-- ================================================================
-- BLOQUE 4: SUBTIPOS DE USUARIO
-- ================================================================

CREATE TABLE Coordinadora_Institucional (
    idCoordInst INT IDENTITY(1,1) PRIMARY KEY,
    idUsuario   INT NOT NULL UNIQUE REFERENCES Usuario(idUsuario)
);
GO

CREATE TABLE Jefe_Departamento (
    idJefeDepto  INT IDENTITY(1,1) PRIMARY KEY,
    departamento NVARCHAR(100),
    idUsuario    INT NOT NULL UNIQUE REFERENCES Usuario(idUsuario)
);
GO

CREATE TABLE Coordinadora_Departamental (
    idCoordDepto INT IDENTITY(1,1) PRIMARY KEY,
    departamento NVARCHAR(100),
    idUsuario    INT NOT NULL UNIQUE REFERENCES Usuario(idUsuario)
);
GO

-- ================================================================
-- BLOQUE 5: PROGRAMA DE TUTORÍAS
-- ================================================================

CREATE TABLE Programa_Tutorias (
    idPrograma   INT IDENTITY(1,1) PRIMARY KEY,
    cicloEscolar NVARCHAR(30)  NOT NULL UNIQUE,
    objetivo     NVARCHAR(500) NULL,
    fechaInicio  DATE          NOT NULL,
    fechaFin     DATE          NOT NULL,
    estado       NVARCHAR(20)  NOT NULL DEFAULT 'Borrador',
    idITC        INT           NOT NULL REFERENCES ITCuliacan(idITC),
    idCoordInst  INT           NOT NULL REFERENCES Coordinadora_Institucional(idCoordInst),
    created_at   DATETIME2     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT chk_estado_programa CHECK (estado IN ('Borrador','Activo','Cerrado')),
    CONSTRAINT chk_fechas_programa CHECK (fechaFin > fechaInicio)
);
GO

-- ================================================================
-- BLOQUE 6: TUTOR
-- ================================================================

CREATE TABLE Tutor (
    noEmpleado     NVARCHAR(20) PRIMARY KEY,
    tipoContrato   NVARCHAR(50) NOT NULL,
    diplomado      BIT          NOT NULL DEFAULT 0,
    cupoDisponible SMALLINT     NOT NULL DEFAULT 25,
    idUsuario      INT          NOT NULL UNIQUE REFERENCES Usuario(idUsuario),
    idJefeDepto    INT          NULL REFERENCES Jefe_Departamento(idJefeDepto),

    CONSTRAINT chk_tipoContrato CHECK (tipoContrato = 'Tiempo Completo'),
    CONSTRAINT chk_cupo         CHECK (cupoDisponible BETWEEN 0 AND 25)
);
GO

-- ================================================================
-- BLOQUE 7: TUTORADO
-- ================================================================

CREATE TABLE Tutorado (
    noControl  NVARCHAR(20)  PRIMARY KEY,
    carrera    NVARCHAR(100) NOT NULL,
    semestre   SMALLINT      NOT NULL,
    estatus    NVARCHAR(30)  NOT NULL DEFAULT 'Activo',
    idUsuario  INT           NOT NULL UNIQUE REFERENCES Usuario(idUsuario),

    CONSTRAINT chk_semestre CHECK (semestre BETWEEN 1 AND 12)
);
GO

-- ================================================================
-- BLOQUE 8: ASIGNACION
-- ================================================================

CREATE TABLE Asignacion (
    idAsignacion INT IDENTITY(1,1) PRIMARY KEY,
    fecha        DATE         NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    periodo      NVARCHAR(50) NOT NULL DEFAULT '',
    estado       NVARCHAR(20) NOT NULL DEFAULT 'Activa',
    aula         NVARCHAR(20) NULL,
    horario      NVARCHAR(50) NULL,
    noEmpleado   NVARCHAR(20) NOT NULL REFERENCES Tutor(noEmpleado),
    noControl    NVARCHAR(20) NOT NULL REFERENCES Tutorado(noControl),
    idPrograma   INT          NOT NULL REFERENCES Programa_Tutorias(idPrograma),
    idCoordDepto INT          NULL REFERENCES Coordinadora_Departamental(idCoordDepto),

    CONSTRAINT chk_estado_asignacion CHECK (estado IN ('Activa','Baja','Completada','Inactiva')),
    CONSTRAINT uq_tutorado_programa  UNIQUE (noControl, idPrograma)
);
GO

CREATE INDEX idx_Asignacion_Tutor    ON Asignacion(noEmpleado);
CREATE INDEX idx_Asignacion_Tutorado ON Asignacion(noControl);
GO

-- Trigger: valida cupo máximo 25
CREATE TRIGGER trg_ValidarCupoTutor
ON Asignacion
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM INSERTED i
        WHERE (SELECT cupoDisponible FROM Tutor WHERE noEmpleado = i.noEmpleado) <= 0
    )
    BEGIN
        RAISERROR(N'El tutor no tiene cupo disponible (máximo 25 tutorados).', 16, 1);
        RETURN;
    END;
    INSERT INTO Asignacion(fecha,periodo,estado,aula,horario,noEmpleado,noControl,idPrograma,idCoordDepto)
    SELECT fecha,periodo,estado,aula,horario,noEmpleado,noControl,idPrograma,idCoordDepto FROM INSERTED;
    UPDATE t SET cupoDisponible = cupoDisponible - 1
    FROM Tutor t INNER JOIN INSERTED i ON t.noEmpleado = i.noEmpleado;
END;
GO

-- ================================================================
-- BLOQUE 9: SESION — con columnas tutorAsistio y fechaLimiteEntrega
-- ================================================================

CREATE TABLE Sesion (
    idSesion           INT IDENTITY(1,1) PRIMARY KEY,
    numSesion          SMALLINT      NOT NULL,
    fecha              DATE          NOT NULL,
    hora               NVARCHAR(10)  NULL,
    aula               NVARCHAR(50)  NULL,
    descripcion        NVARCHAR(MAX) NULL,
    conEvidencia       BIT           NOT NULL DEFAULT 0,
    tutorAsistio       BIT           NOT NULL DEFAULT 1,
    fechaLimiteEntrega DATE          NULL,
    noEmpleado         NVARCHAR(20)  NOT NULL REFERENCES Tutor(noEmpleado),
    idPrograma         INT           NOT NULL REFERENCES Programa_Tutorias(idPrograma),
    created_at         DATETIME2     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT chk_numSesion CHECK (numSesion BETWEEN 1 AND 8)
);
GO

CREATE INDEX idx_Sesion_Tutor    ON Sesion(noEmpleado);
CREATE INDEX idx_Sesion_Programa ON Sesion(idPrograma);
GO

-- ================================================================
-- BLOQUE 10: ASISTENCIA
-- ================================================================

CREATE TABLE Asistencia (
    idAsistencia INT IDENTITY(1,1) PRIMARY KEY,
    idSesion     INT          NOT NULL REFERENCES Sesion(idSesion),
    noControl    NVARCHAR(20) NOT NULL REFERENCES Tutorado(noControl),
    asistio      BIT          NOT NULL DEFAULT 0,
    CONSTRAINT uq_asistencia UNIQUE (idSesion, noControl)
);
GO

CREATE INDEX idx_Asistencia_Sesion   ON Asistencia(idSesion);
CREATE INDEX idx_Asistencia_Tutorado ON Asistencia(noControl);
GO

-- ================================================================
-- BLOQUE 11: EVIDENCIA — con columnas calificacion y observaciones
-- ================================================================

CREATE TABLE Evidencia (
    idEvidencia    INT IDENTITY(1,1) PRIMARY KEY,
    tipoEvidencia  NVARCHAR(30)  NOT NULL DEFAULT 'Otro',
    tipoArchivo    NVARCHAR(10)  NOT NULL,
    nombreArchivo  NVARCHAR(255) NOT NULL,
    rutaArchivo    NVARCHAR(500) NOT NULL,
    descripcion    NVARCHAR(MAX) NULL,
    fechaCarga     DATETIME2     NOT NULL DEFAULT GETDATE(),
    estado         NVARCHAR(20)  NOT NULL DEFAULT 'Activa',
    calificacion   NVARCHAR(30)  NULL,
    observaciones  NVARCHAR(500) NULL,
    idSesion       INT           NULL REFERENCES Sesion(idSesion),
    idCanalizacion INT           NULL,
    noControl      NVARCHAR(20)  NULL REFERENCES Tutorado(noControl),
    cargadoPor     INT           NOT NULL REFERENCES Usuario(idUsuario),

    CONSTRAINT chk_tipoEvidencia CHECK (tipoEvidencia IN ('Lista Asistencia','Actividad','Reporte','Canalizacion','Otro')),
    CONSTRAINT chk_tipoArchivo   CHECK (tipoArchivo IN ('pdf','jpg','jpeg','png','xlsx','docx')),
    CONSTRAINT chk_estado_evid   CHECK (estado IN ('Activa','Archivada'))
);
GO

CREATE INDEX idx_Evidencia_Sesion   ON Evidencia(idSesion);
CREATE INDEX idx_Evidencia_Tutorado ON Evidencia(noControl);
GO

CREATE TRIGGER trg_NoEliminarEvidencias
ON Evidencia INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Evidencia SET estado = 'Archivada' WHERE idEvidencia IN (SELECT idEvidencia FROM DELETED);
END;
GO

CREATE TRIGGER trg_MarcarSesionConEvidencia
ON Evidencia AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Sesion SET conEvidencia = 1 WHERE idSesion IN (SELECT idSesion FROM INSERTED WHERE idSesion IS NOT NULL);
END;
GO

-- ================================================================
-- BLOQUE 12: EVALUACION — con constraint actualizado
-- ================================================================

CREATE TABLE Evaluacion (
    idEvaluacion    INT IDENTITY(1,1) PRIMARY KEY,
    promedio        DECIMAL(4,2)  NULL,
    statusDesempeno NVARCHAR(20)  NULL,
    estado          NVARCHAR(20)  NOT NULL DEFAULT 'Abierta',
    fechaRegistro   DATETIME2     NOT NULL DEFAULT GETDATE(),
    validadoPor     INT           NULL REFERENCES Usuario(idUsuario),
    fechaValidacion DATETIME2     NULL,
    noControl       NVARCHAR(20)  NOT NULL REFERENCES Tutorado(noControl),
    noEmpleado      NVARCHAR(20)  NOT NULL REFERENCES Tutor(noEmpleado),
    idPrograma      INT           NOT NULL REFERENCES Programa_Tutorias(idPrograma),

    -- Constraint actualizado para incluir nuevos niveles de desempeño
    CONSTRAINT chk_statusDesempeno CHECK (
        statusDesempeno IS NULL OR statusDesempeno IN (
            'Sobresaliente','Satisfactorio','Regular','Deficiente',
            'Excelente','Bueno','Aceptable','Suficiente'
        )
    ),
    CONSTRAINT chk_estado_eval CHECK (estado IN ('Abierta','Cerrada','Validada')),
    CONSTRAINT uq_evaluacion   UNIQUE (noControl, idPrograma)
);
GO

CREATE INDEX idx_Evaluacion_Tutorado ON Evaluacion(noControl);
CREATE INDEX idx_Evaluacion_Tutor    ON Evaluacion(noEmpleado);
GO

CREATE TRIGGER trg_ProtegerEvaluacionValidada
ON Evaluacion AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM DELETED WHERE estado = 'Validada')
    BEGIN
        RAISERROR(N'La evaluación ya fue validada y no puede modificarse.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- ================================================================
-- BLOQUE 13: CRITERIO EVALUACION
-- ================================================================

CREATE TABLE CriterioEvaluacion (
    idCriterio      INT IDENTITY(1,1) PRIMARY KEY,
    idEvaluacion    INT      NOT NULL REFERENCES Evaluacion(idEvaluacion),
    numeroCriterio  SMALLINT NOT NULL,
    valor           SMALLINT NOT NULL,

    CONSTRAINT chk_numeroCriterio CHECK (numeroCriterio BETWEEN 1 AND 7),
    CONSTRAINT chk_valorCriterio  CHECK (valor BETWEEN 1 AND 4),
    CONSTRAINT uq_criterio        UNIQUE (idEvaluacion, numeroCriterio)
);
GO

-- ================================================================
-- BLOQUE 14: CANALIZACION
-- ================================================================

CREATE TABLE Canalizacion (
    idCanalizacion    INT IDENTITY(1,1) PRIMARY KEY,
    tipoAtencion      NVARCHAR(20)  NOT NULL,
    motivo            NVARCHAR(MAX) NOT NULL,
    fechaCanalizacion DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    estatus           NVARCHAR(20)  NOT NULL DEFAULT 'Pendiente',
    observaciones     NVARCHAR(MAX) NULL,
    noControl         NVARCHAR(20)  NOT NULL REFERENCES Tutorado(noControl),
    noEmpleado        NVARCHAR(20)  NOT NULL REFERENCES Tutor(noEmpleado),
    idPrograma        INT           NOT NULL REFERENCES Programa_Tutorias(idPrograma),
    created_at        DATETIME2     NOT NULL DEFAULT GETDATE(),

    CONSTRAINT chk_tipoAtencion  CHECK (tipoAtencion IN ('Psicologica','Academica','Medica','Becas','Otra')),
    CONSTRAINT chk_estatus_canal CHECK (estatus IN ('Pendiente','En Seguimiento','Cerrada'))
);
GO

CREATE INDEX idx_Canalizacion_Tutorado ON Canalizacion(noControl);
GO

ALTER TABLE Evidencia ADD CONSTRAINT FK_Evidencia_Canalizacion
    FOREIGN KEY(idCanalizacion) REFERENCES Canalizacion(idCanalizacion);
GO

-- ================================================================
-- BLOQUE 15: FALTA TUTOR
-- ================================================================

CREATE TABLE FaltaTutor (
    idFalta       INT            IDENTITY(1,1) PRIMARY KEY,
    noEmpleado    NVARCHAR(20)   NOT NULL,
    idSesion      INT            NOT NULL,
    fechaRegistro DATETIME2      NOT NULL DEFAULT GETDATE(),
    observaciones NVARCHAR(500)  NULL,
    CONSTRAINT FK_FaltaTutor_Tutor  FOREIGN KEY (noEmpleado) REFERENCES Tutor(noEmpleado),
    CONSTRAINT FK_FaltaTutor_Sesion FOREIGN KEY (idSesion)   REFERENCES Sesion(idSesion),
    CONSTRAINT UQ_FaltaTutor        UNIQUE (noEmpleado, idSesion)
);
GO

-- ================================================================
-- BLOQUE 16: BAJA
-- ================================================================

CREATE TABLE Baja (
    idBaja              INT IDENTITY(1,1) PRIMARY KEY,
    motivoBaja          NVARCHAR(30) NOT NULL,
    fechaUltimaSesion   DATE         NULL,
    fechaRegistro       DATETIME2    NOT NULL DEFAULT GETDATE(),
    noControl           NVARCHAR(20) NOT NULL REFERENCES Tutorado(noControl),
    noEmpleado          NVARCHAR(20) NOT NULL REFERENCES Tutor(noEmpleado),
    idPrograma          INT          NOT NULL REFERENCES Programa_Tutorias(idPrograma),
    registradoPor       INT          NOT NULL REFERENCES Usuario(idUsuario),

    CONSTRAINT chk_motivoBaja CHECK (motivoBaja IN ('Problemas Personales','Abandono','Cambio Institucion','Otro')),
    CONSTRAINT uq_baja        UNIQUE (noControl, idPrograma)
);
GO

CREATE TRIGGER trg_ProcesarBaja
ON Baja AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Tutorado SET estatus = 'Baja' WHERE noControl IN (SELECT noControl FROM INSERTED);
    UPDATE a SET a.estado = 'Baja' FROM Asignacion a
    INNER JOIN INSERTED i ON a.noControl=i.noControl AND a.noEmpleado=i.noEmpleado AND a.idPrograma=i.idPrograma;
    UPDATE t SET t.cupoDisponible = t.cupoDisponible + 1 FROM Tutor t INNER JOIN INSERTED i ON t.noEmpleado=i.noEmpleado;
    UPDATE e SET e.statusDesempeno='Deficiente', e.estado='Cerrada' FROM Evaluacion e
    INNER JOIN INSERTED i ON e.noControl=i.noControl AND e.idPrograma=i.idPrograma WHERE e.estado='Abierta';
END;
GO

-- ================================================================
-- BLOQUE 17: ACTIVIDAD — con todas las columnas requeridas
-- ================================================================

CREATE TABLE Actividad (
    idActividad        INT            IDENTITY(1,1) PRIMARY KEY,
    idPrograma         INT            NOT NULL REFERENCES Programa_Tutorias(idPrograma),
    titulo             NVARCHAR(200)  NOT NULL,
    descripcion        NVARCHAR(MAX)  NULL,
    tipoActividad      VARCHAR(50)    NOT NULL,
    fechaLimite        DATE           NULL,
    fechaCreacion      DATETIME2      NOT NULL DEFAULT GETDATE(),
    estado             VARCHAR(30)    NOT NULL DEFAULT 'Pendiente',
    fechaModificacion  DATETIME2      NULL,
    creadaPor          INT            NULL,
    modificadaPor      INT            NULL,
    notasTutor         NVARCHAR(MAX)  NULL
);
GO

-- ================================================================
-- BLOQUE 18: INFORME INTERMEDIO
-- ================================================================

CREATE TABLE InformeIntermedio (
    idInforme     INT IDENTITY(1,1) PRIMARY KEY,
    observaciones NVARCHAR(MAX) NULL,
    estado        NVARCHAR(20)  NOT NULL DEFAULT 'Borrador',
    created_at    DATETIME2     NOT NULL DEFAULT GETDATE(),
    updated_at    DATETIME2     NOT NULL DEFAULT GETDATE(),
    noEmpleado    NVARCHAR(20)  NOT NULL REFERENCES Tutor(noEmpleado),
    idPrograma    INT           NOT NULL REFERENCES Programa_Tutorias(idPrograma),

    CONSTRAINT chk_estado_informe CHECK (estado IN ('Borrador','Enviado','Validado'))
);
GO

CREATE TRIGGER trg_ValidarSesionesInforme
ON InformeIntermedio INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM INSERTED i
        WHERE (SELECT COUNT(*) FROM Sesion s WHERE s.noEmpleado=i.noEmpleado AND s.idPrograma=i.idPrograma) < 4
    )
    BEGIN
        RAISERROR(N'Se requieren al menos 4 sesiones para generar el informe intermedio.', 16, 1);
        RETURN;
    END;
    INSERT INTO InformeIntermedio (observaciones,estado,created_at,updated_at,noEmpleado,idPrograma)
    SELECT observaciones,estado,created_at,updated_at,noEmpleado,idPrograma FROM INSERTED;
END;
GO

-- ================================================================
-- BLOQUE 19: BITACORA
-- ================================================================

CREATE TABLE Bitacora (
    idBitacora      INT IDENTITY(1,1) PRIMARY KEY,
    accion          NVARCHAR(20)  NOT NULL,
    tablaAfectada   NVARCHAR(50)  NOT NULL,
    registroId      INT           NULL,
    datosAnteriores NVARCHAR(MAX) NULL,
    datosNuevos     NVARCHAR(MAX) NULL,
    fechaHora       DATETIME2     NOT NULL DEFAULT GETDATE(),
    idUsuario       INT           NOT NULL REFERENCES Usuario(idUsuario),

    CONSTRAINT chk_accion CHECK (accion IN ('Crear','Editar','Desactivar','Consultar','Eliminar'))
);
GO

CREATE INDEX idx_Bitacora_Usuario ON Bitacora(idUsuario);
CREATE INDEX idx_Bitacora_Tabla   ON Bitacora(tablaAfectada);
CREATE INDEX idx_Bitacora_Fecha   ON Bitacora(fechaHora);
GO

-- ================================================================
-- BLOQUE 20: STORED PROCEDURES — versiones corregidas
-- ================================================================

-- sp_CrearTutor: sin cambios
CREATE PROCEDURE sp_CrearTutor
    @nombre       NVARCHAR(150),
    @correoInst   NVARCHAR(150),
    @tipoContrato NVARCHAR(50),
    @diplomado    BIT,
    @noEmpleado   NVARCHAR(20),
    @idJefeDepto  INT
AS
BEGIN
    DECLARE @idUsuario INT;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF @tipoContrato <> 'Tiempo Completo'
        BEGIN RAISERROR(N'Solo se permite Tiempo Completo.', 16, 1); ROLLBACK TRANSACTION; RETURN; END;
        IF @diplomado = 0
        BEGIN RAISERROR(N'El maestro no cuenta con el diplomado requerido.', 16, 1); ROLLBACK TRANSACTION; RETURN; END;

        INSERT INTO Usuario(nombre,correoInst,rol,estado,numEmpleado)
        VALUES(@nombre,@correoInst,'Tutor','Activo',@noEmpleado);
        SET @idUsuario = SCOPE_IDENTITY();

        INSERT INTO UsuarioRol(idUsuario,idRol)
        SELECT @idUsuario, idRol FROM Roles WHERE nombreRol = 'Tutor';

        INSERT INTO Tutor(noEmpleado,tipoContrato,diplomado,cupoDisponible,idUsuario,idJefeDepto)
        VALUES(@noEmpleado,@tipoContrato,@diplomado,25,@idUsuario,@idJefeDepto);

        COMMIT TRANSACTION;
        PRINT N'Tutor creado exitosamente.';
    END TRY
    BEGIN CATCH ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

-- sp_CrearTutorado: con validación de duplicados
CREATE PROCEDURE sp_CrearTutorado
    @nombre     NVARCHAR(150),
    @correoInst NVARCHAR(150),
    @noControl  NVARCHAR(20),
    @carrera    NVARCHAR(100),
    @semestre   INT
AS
BEGIN
    DECLARE @idUsuario INT;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Validar número de control duplicado
        IF EXISTS (SELECT 1 FROM Tutorado WHERE noControl = @noControl)
        BEGIN
            RAISERROR(N'Ya existe un tutorado con ese número de control.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END;

        -- Validar correo duplicado
        IF EXISTS (SELECT 1 FROM Usuario WHERE correoInst = @correoInst)
        BEGIN
            RAISERROR(N'Ya existe un usuario con ese correo institucional.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END;

        INSERT INTO Usuario(nombre,correoInst,rol,estado,numControl)
        VALUES(@nombre,@correoInst,'Tutorado','Activo',@noControl);
        SET @idUsuario = SCOPE_IDENTITY();

        INSERT INTO UsuarioRol(idUsuario,idRol)
        SELECT @idUsuario, idRol FROM Roles WHERE nombreRol = 'Tutorado';

        INSERT INTO Tutorado(noControl,carrera,semestre,estatus,idUsuario)
        VALUES(@noControl,@carrera,@semestre,'Activo',@idUsuario);

        COMMIT TRANSACTION;
        PRINT N'Tutorado creado exitosamente.';
    END TRY
    BEGIN CATCH ROLLBACK TRANSACTION; THROW; END CATCH;
END;
GO

CREATE PROCEDURE sp_AsignarTutorado
    @noEmpleado   NVARCHAR(20),
    @noControl    NVARCHAR(20),
    @periodo      NVARCHAR(50),
    @idPrograma   INT,
    @idCoordDepto INT = NULL
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Asignacion(fecha,periodo,estado,noEmpleado,noControl,idPrograma,idCoordDepto)
        VALUES(CAST(GETDATE() AS DATE),@periodo,'Activa',@noEmpleado,@noControl,@idPrograma,@idCoordDepto);
        COMMIT TRANSACTION;
        PRINT N'Asignación registrada correctamente.';
    END TRY
    BEGIN CATCH ROLLBACK TRANSACTION; PRINT ERROR_MESSAGE(); END CATCH;
END;
GO

-- sp_EvaluarTutorado: con promedio redondeado en escala 4 y niveles actualizados
CREATE PROCEDURE sp_EvaluarTutorado
    @noControl  NVARCHAR(20),
    @noEmpleado NVARCHAR(20),
    @idPrograma INT,
    @c1 SMALLINT, @c2 SMALLINT, @c3 SMALLINT, @c4 SMALLINT,
    @c5 SMALLINT, @c6 SMALLINT, @c7 SMALLINT
AS
BEGIN
    DECLARE @idEvaluacion INT;
    DECLARE @promedio     DECIMAL(5,2);
    DECLARE @promRedondo  INT;
    DECLARE @status       NVARCHAR(30);

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Evaluacion(noControl, noEmpleado, idPrograma)
        VALUES(@noControl, @noEmpleado, @idPrograma);
        SET @idEvaluacion = SCOPE_IDENTITY();

        INSERT INTO CriterioEvaluacion(idEvaluacion, numeroCriterio, valor) VALUES
            (@idEvaluacion,1,@c1),(@idEvaluacion,2,@c2),(@idEvaluacion,3,@c3),
            (@idEvaluacion,4,@c4),(@idEvaluacion,5,@c5),(@idEvaluacion,6,@c6),
            (@idEvaluacion,7,@c7);

        -- Promedio exacto en escala 1-4
        SET @promedio    = CAST(@c1+@c2+@c3+@c4+@c5+@c6+@c7 AS DECIMAL(5,2)) / 7.0;
        -- Redondeado al entero más cercano
        SET @promRedondo = ROUND(@promedio, 0);

        -- Nivel de desempeño según escala 1-4
        SET @status = CASE @promRedondo
            WHEN 4 THEN 'Excelente'
            WHEN 3 THEN 'Bueno'
            WHEN 2 THEN 'Aceptable'
            ELSE        'Suficiente'
        END;

        UPDATE Evaluacion
        SET promedio = @promRedondo, statusDesempeno = @status, estado = 'Cerrada'
        WHERE idEvaluacion = @idEvaluacion;

        COMMIT TRANSACTION;
        PRINT N'Evaluación registrada correctamente.';
    END TRY
    BEGIN CATCH ROLLBACK TRANSACTION; PRINT ERROR_MESSAGE(); END CATCH;
END;
GO

CREATE PROCEDURE sp_RegistrarBaja
    @noControl         NVARCHAR(20),
    @noEmpleado        NVARCHAR(20),
    @idPrograma        INT,
    @motivoBaja        NVARCHAR(30),
    @fechaUltimaSesion DATE = NULL,
    @registradoPor     INT
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Baja(motivoBaja,fechaUltimaSesion,noControl,noEmpleado,idPrograma,registradoPor)
        VALUES(@motivoBaja,@fechaUltimaSesion,@noControl,@noEmpleado,@idPrograma,@registradoPor);
        COMMIT TRANSACTION;
        PRINT N'Baja registrada correctamente.';
    END TRY
    BEGIN CATCH ROLLBACK TRANSACTION; PRINT ERROR_MESSAGE(); END CATCH;
END;
GO

CREATE PROCEDURE sp_RegistrarSesion
    @numSesion   INT,
    @fecha       DATE,
    @aula        NVARCHAR(50),
    @descripcion NVARCHAR(MAX) = NULL,
    @noEmpleado  NVARCHAR(20),
    @idPrograma  INT
AS
BEGIN
    INSERT INTO Sesion(numSesion,fecha,aula,descripcion,noEmpleado,idPrograma)
    VALUES(@numSesion,@fecha,@aula,@descripcion,@noEmpleado,@idPrograma);
    PRINT N'Sesión registrada.';
END;
GO

-- ================================================================
-- BLOQUE 21: VISTAS — actualizadas con nuevos niveles
-- ================================================================

CREATE VIEW vw_Tutores AS
    SELECT T.noEmpleado, U.nombre, U.correoInst, U.estado,
           T.tipoContrato, T.diplomado, T.cupoDisponible,
           25 - T.cupoDisponible AS tutoradosAsignados
    FROM   Tutor T INNER JOIN Usuario U ON T.idUsuario = U.idUsuario;
GO

CREATE VIEW vw_Tutorados AS
    SELECT T.noControl, U.nombre, U.correoInst, T.carrera, T.semestre, T.estatus
    FROM   Tutorado T INNER JOIN Usuario U ON T.idUsuario = U.idUsuario;
GO

CREATE VIEW vw_TutoradosAcreditados AS
    SELECT T.noControl, U.nombre, T.carrera,
           E.promedio, E.statusDesempeno, P.cicloEscolar
    FROM   Evaluacion E
    JOIN   Tutorado T ON T.noControl = E.noControl
    JOIN   Usuario  U ON U.idUsuario = T.idUsuario
    JOIN   Programa_Tutorias P ON P.idPrograma = E.idPrograma
    WHERE  E.estado IN ('Cerrada','Validada')
    AND    E.statusDesempeno IN (
               'Sobresaliente','Satisfactorio','Regular',
               'Excelente','Bueno','Aceptable','Suficiente'
           )
    AND    T.estatus = 'Activo';
GO

CREATE VIEW vw_CargaTutores AS
    SELECT T.noEmpleado, U.nombre AS tutor,
           T.cupoDisponible, 25 - T.cupoDisponible AS tutoradosAsignados,
           P.cicloEscolar
    FROM   Tutor T
    JOIN   Usuario U ON U.idUsuario = T.idUsuario
    JOIN   Programa_Tutorias P ON P.estado = 'Activo';
GO

CREATE VIEW vw_AsistenciaTutorado AS
    SELECT A.noControl, U.nombre,
           COUNT(*) AS totalSesiones,
           SUM(CASE WHEN A.asistio=1 THEN 1 ELSE 0 END) AS sesionesAsistidas,
           ROUND(CAST(SUM(CASE WHEN A.asistio=1 THEN 1 ELSE 0 END) AS DECIMAL(10,1))
                 / NULLIF(COUNT(*),0)*100, 1) AS porcentajeAsistencia
    FROM   Asistencia A
    JOIN   Tutorado T ON T.noControl = A.noControl
    JOIN   Usuario  U ON U.idUsuario = T.idUsuario
    GROUP BY A.noControl, U.nombre;
GO

CREATE VIEW vw_ReporteEstadistico AS
    SELECT P.cicloEscolar, T.carrera,
           COUNT(DISTINCT A.noEmpleado) AS totalTutores,
           COUNT(DISTINCT A.noControl)  AS totalTutorados,
           ROUND(AVG(ast.porcentaje), 1) AS promedioAsistencia,
           COUNT(DISTINCT B.idBaja)     AS totalBajas
    FROM   Asignacion A
    JOIN   Programa_Tutorias P ON P.idPrograma = A.idPrograma
    JOIN   Tutorado T ON T.noControl = A.noControl
    LEFT JOIN (
        SELECT noControl,
               ROUND(CAST(SUM(CASE WHEN asistio=1 THEN 1 ELSE 0 END) AS DECIMAL(10,1))
                     / NULLIF(COUNT(*),0)*100, 1) AS porcentaje
        FROM Asistencia GROUP BY noControl
    ) ast ON ast.noControl = A.noControl
    LEFT JOIN Baja B ON B.noControl=A.noControl AND B.idPrograma=A.idPrograma
    GROUP BY P.cicloEscolar, T.carrera;
GO

-- ================================================================
-- BLOQUE 22: SEGURIDAD
-- ================================================================

CREATE ROLE Rol_Admin_Tutorias;
CREATE ROLE Rol_Tutor;
CREATE ROLE Rol_Solo_Lectura;
GO

GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO Rol_Admin_Tutorias;
GO

GRANT SELECT        ON vw_Tutorados        TO Rol_Tutor;
GRANT SELECT        ON vw_CargaTutores     TO Rol_Tutor;
GRANT SELECT, INSERT, UPDATE ON Sesion     TO Rol_Tutor;
GRANT SELECT, INSERT ON Asistencia         TO Rol_Tutor;
GRANT SELECT, INSERT ON Evidencia          TO Rol_Tutor;
GRANT SELECT, INSERT, UPDATE ON Evaluacion TO Rol_Tutor;
GRANT SELECT, INSERT ON CriterioEvaluacion TO Rol_Tutor;
GRANT SELECT, INSERT ON Canalizacion       TO Rol_Tutor;
GRANT SELECT, INSERT ON InformeIntermedio  TO Rol_Tutor;
GO

GRANT SELECT TO Rol_Solo_Lectura;
GO

-- Usuario SQL para autenticación del backend Node.js
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'sgt_user')
BEGIN
    CREATE LOGIN sgt_user WITH PASSWORD = 'Sgt2025!';
END;
GO

CREATE USER sgt_user FOR LOGIN sgt_user;
GO
ALTER ROLE db_owner ADD MEMBER sgt_user;
GO

-- ================================================================
-- BLOQUE 23: DATOS DE PRUEBA COMPLETOS
-- Contraseña de todos los usuarios: password
-- ================================================================

-- Institución
INSERT INTO TECNM(claveInstitucional) VALUES ('TECNM-2025');
INSERT INTO ITCuliacan(nombre, direccion, telefono, idTecnm)
VALUES ('IT Culiacán','Juan de Dios Bátiz S/N, Col. Guadalupe','6677138300',1);
GO

-- Usuarios administrativos y tutores
INSERT INTO Usuario(nombre, correoInst, passwordHash, rol, estado, numEmpleado) VALUES
('Rosa López',     'rosa.lopez@culiacan.tecnm.mx',     '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Coordinadora Institucional', 'Activo', 'EMP001'),
('Ramón Soto',     'ramon.soto@culiacan.tecnm.mx',     '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Jefe Departamento',          'Activo', 'EMP002'),
('María Torres',   'maria.torres@culiacan.tecnm.mx',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Coordinadora Departamental', 'Activo', 'EMP003'),
('Juan Pérez',     'juan.perez@culiacan.tecnm.mx',     '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutor',                      'Activo', '2025001'),
('Ana García',     'ana.garcia@culiacan.tecnm.mx',     '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutor',                      'Activo', '2025002'),
('Carlos Méndez',  'carlos.mendez@culiacan.tecnm.mx',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Director',                   'Activo', 'EMP006'),
('Patricia Lugo',  'patricia.lugo@culiacan.tecnm.mx',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Subdirector',                'Activo', 'EMP007'),
('Roberto Félix',  'roberto.felix@culiacan.tecnm.mx',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Jefe Departamento',          'Activo', 'EMP008'),
('Lucía Valdez',   'lucia.valdez@culiacan.tecnm.mx',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Coordinadora Departamental', 'Activo', 'EMP009'),
('Miguel Osuna',   'miguel.osuna@culiacan.tecnm.mx',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutor',                      'Activo', '2025003'),
('Sandra Castro',  'sandra.castro@culiacan.tecnm.mx',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutor',                      'Activo', '2025004'),
('Jorge Lizárraga','jorge.lizarraga@culiacan.tecnm.mx','$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutor',                      'Activo', '2025005');
GO

-- Subtipos
INSERT INTO Coordinadora_Institucional(idUsuario)               VALUES (1);
INSERT INTO Jefe_Departamento(departamento, idUsuario)          VALUES ('Ing. Sistemas Computacionales', 2);
INSERT INTO Jefe_Departamento(departamento, idUsuario)          VALUES ('Ing. Industrial', 8);
INSERT INTO Coordinadora_Departamental(departamento, idUsuario) VALUES ('Ing. Sistemas Computacionales', 3);
INSERT INTO Coordinadora_Departamental(departamento, idUsuario) VALUES ('Ing. Industrial', 9);
GO

-- Programa activo
INSERT INTO Programa_Tutorias(cicloEscolar, objetivo, fechaInicio, fechaFin, estado, idITC, idCoordInst)
VALUES ('2025-A','Reducir deserción y reprobación en alumnos de nuevo ingreso','2025-01-20','2025-06-30','Activo',1,1);
GO

-- Tutores
INSERT INTO Tutor(noEmpleado, tipoContrato, diplomado, cupoDisponible, idUsuario, idJefeDepto)
VALUES ('2025001','Tiempo Completo',1,25,4,1),
       ('2025002','Tiempo Completo',1,25,5,1),
       ('2025003','Tiempo Completo',1,25,10,2),
       ('2025004','Tiempo Completo',1,25,11,2),
       ('2025005','Tiempo Completo',1,25,12,2);
GO

-- Tutorados — Ing. Sistemas Computacionales
INSERT INTO Usuario(nombre, correoInst, passwordHash, rol, estado, numControl) VALUES
('Carlos Mendoza',             'carlos.mendoza@culiacan.tecnm.mx',             '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170001'),
('Laura Rivas',                'laura.rivas@culiacan.tecnm.mx',                '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170002'),
('Ricardo Bojórquez',          'ricardo.bojorquez@culiacan.tecnm.mx',          '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170009'),
('Karla Inzunza',              'karla.inzunza@culiacan.tecnm.mx',              '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170010'),
('Francia Ximena Zepeda Alcaraz','francia.zepeda@culiacan.tecnm.mx',           '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170859'),
('Jose Carlos Osuna Tirado',   'josecarlos.osuna@culiacan.tecnm.mx',           '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170759'),
('Jesus Eugenio Soto Cortez',  'jesus.soto@culiacan.tecnm.mx',                 '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170829');

-- Tutorados — otras carreras
INSERT INTO Usuario(nombre, correoInst, passwordHash, rol, estado, numControl) VALUES
('Pedro Olmedo',  'pedro.olmedo@culiacan.tecnm.mx',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170003'),
('Diana Parra',   'diana.parra@culiacan.tecnm.mx',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170004'),
('Héctor Rojas',  'hector.rojas@culiacan.tecnm.mx',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170005'),
('Valeria Ibarra','valeria.ibarra@culiacan.tecnm.mx','$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170006'),
('Luis Angulo',   'luis.angulo@culiacan.tecnm.mx',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170007'),
('Fernanda Meza', 'fernanda.meza@culiacan.tecnm.mx', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Tutorado','Activo','22170008');
GO

-- Tabla Tutorado
INSERT INTO Tutorado(noControl, carrera, semestre, estatus, idUsuario) VALUES
('22170001','Ing. Sistemas Computacionales',1,'Activo',13),
('22170002','Ing. Sistemas Computacionales',1,'Activo',14),
('22170009','Ing. Sistemas Computacionales',1,'Activo',15),
('22170010','Ing. Sistemas Computacionales',1,'Activo',16),
('22170859','Ing. Sistemas Computacionales',6,'Activo',17),
('22170759','Ing. Sistemas Computacionales',6,'Activo',18),
('22170829','Ing. Sistemas Computacionales',6,'Activo',19),
('22170003','Ing. Industrial',              1,'Activo',20),
('22170004','Ing. Industrial',              1,'Activo',21),
('22170005','Ing. Electronica',             1,'Activo',22),
('22170006','Ing. Electronica',             1,'Activo',23),
('22170007','Ing. Gestion Empresarial',     1,'Activo',24),
('22170008','Ing. Gestion Empresarial',     1,'Activo',25);
GO

-- Asignaciones
EXEC sp_AsignarTutorado '2025001','22170001','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025001','22170002','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025001','22170009','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025002','22170010','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025002','22170859','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025003','22170003','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025003','22170004','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025004','22170005','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025004','22170006','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025005','22170007','Ene-Jun 2026',1;
EXEC sp_AsignarTutorado '2025005','22170008','Ene-Jun 2026',1;
GO

-- Asignaciones de los integrantes del equipo para pruebas
INSERT INTO Asignacion(noEmpleado, noControl, idPrograma, periodo, estado)
VALUES ('2025001','22170759',1,'Ene-Jun 2026','Activa');
INSERT INTO Asignacion(noEmpleado, noControl, idPrograma, periodo, estado)
VALUES ('2025001','22170829',1,'Ene-Jun 2026','Activa');
GO

-- Sesiones de prueba
EXEC sp_RegistrarSesion 1,'2025-02-03','A-12','Presentación del programa de tutorías','2025001',1;
EXEC sp_RegistrarSesion 2,'2025-02-17','A-12','Diagnóstico inicial del grupo','2025001',1;
EXEC sp_RegistrarSesion 3,'2025-03-03','A-12','Seguimiento académico','2025001',1;
EXEC sp_RegistrarSesion 1,'2025-02-03','B-05','Presentación del programa','2025002',1;
EXEC sp_RegistrarSesion 2,'2025-02-17','B-05','Diagnóstico inicial','2025002',1;
GO

-- Evaluaciones de prueba con escala 1-4
EXEC sp_EvaluarTutorado '22170859','2025002',1, 4,4,4,4,4,4,4;
EXEC sp_EvaluarTutorado '22170001','2025001',1, 4,4,3,4,3,3,4;
GO

-- ================================================================
-- BLOQUE 24: VERIFICACIÓN FINAL
-- ================================================================

SELECT 'TECNM'          AS Tabla, COUNT(*) AS Total FROM TECNM            UNION ALL
SELECT 'ITCuliacan',              COUNT(*)           FROM ITCuliacan       UNION ALL
SELECT 'Usuarios',                COUNT(*)           FROM Usuario          UNION ALL
SELECT 'Roles',                   COUNT(*)           FROM Roles            UNION ALL
SELECT 'Tutores',                 COUNT(*)           FROM Tutor            UNION ALL
SELECT 'Tutorados',               COUNT(*)           FROM Tutorado         UNION ALL
SELECT 'Programas',               COUNT(*)           FROM Programa_Tutorias UNION ALL
SELECT 'Asignaciones',            COUNT(*)           FROM Asignacion       UNION ALL
SELECT 'Sesiones',                COUNT(*)           FROM Sesion           UNION ALL
SELECT 'Evaluaciones',            COUNT(*)           FROM Evaluacion       UNION ALL
SELECT 'Canalizaciones',          COUNT(*)           FROM Canalizacion     UNION ALL
SELECT 'Actividades',             COUNT(*)           FROM Actividad        UNION ALL
SELECT 'FaltaTutor',              COUNT(*)           FROM FaltaTutor       UNION ALL
SELECT 'Informes',                COUNT(*)           FROM InformeIntermedio UNION ALL
SELECT 'Bitacora',                COUNT(*)           FROM Bitacora;

SELECT '✅ Base de datos SGT v3 creada correctamente' AS Resultado;
GO
