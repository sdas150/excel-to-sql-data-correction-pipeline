/* =========================================================
   01_create_schema.sql
   Creates the demo database, schemas, and tables.
   ========================================================= */
IF DB_ID('DataCorrectionDemo') IS NULL
    CREATE DATABASE DataCorrectionDemo;
GO
USE DataCorrectionDemo;
GO

IF SCHEMA_ID('stg')   IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('audit') IS NULL EXEC('CREATE SCHEMA audit');
GO

-- Drop in dependency order (safe rerun)
IF OBJECT_ID('audit.ChangeLog')       IS NOT NULL DROP TABLE audit.ChangeLog;
IF OBJECT_ID('stg.OrderCorrections')  IS NOT NULL DROP TABLE stg.OrderCorrections;
IF OBJECT_ID('audit.BatchRun')        IS NOT NULL DROP TABLE audit.BatchRun;
IF OBJECT_ID('dbo.Orders')            IS NOT NULL DROP TABLE dbo.Orders;
GO

-- Target table
CREATE TABLE dbo.Orders (
    OrderID        INT           NOT NULL PRIMARY KEY,
    CustomerID     INT           NOT NULL,
    OrderDate      DATE          NOT NULL,
    OrderStatus    VARCHAR(20)   NOT NULL,
    ShipDate       DATE          NULL,
    Amount         DECIMAL(10,2) NOT NULL,
    ModifiedDate   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    ModifiedBy     VARCHAR(100)  NOT NULL DEFAULT SUSER_SNAME()
);

-- Batch tracking
CREATE TABLE audit.BatchRun (
    BatchID        INT IDENTITY(1,1) PRIMARY KEY,
    SourceFile     VARCHAR(260)   NOT NULL,
    StartTime      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    EndTime        DATETIME2      NULL,
    TotalRows      INT            NULL,
    ValidRows      INT            NULL,
    RejectedRows   INT            NULL,
    UpdatedRows    INT            NULL,
    Status         VARCHAR(20)    NOT NULL DEFAULT 'STARTED',  -- STARTED / VALIDATED / COMPLETED / FAILED
    ErrorMessage   NVARCHAR(4000) NULL
);

-- Staging table (text columns so bad Excel values load and can be rejected with a reason)
CREATE TABLE stg.OrderCorrections (
    StgID            INT IDENTITY(1,1) PRIMARY KEY,
    BatchID          INT          NOT NULL REFERENCES audit.BatchRun(BatchID),
    ExcelRowNum      INT          NOT NULL,
    OrderID          VARCHAR(50)  NULL,
    NewOrderStatus   VARCHAR(50)  NULL,
    NewShipDate      VARCHAR(50)  NULL,
    RequestedBy      VARCHAR(100) NULL,
    ValidationStatus VARCHAR(20)  NOT NULL DEFAULT 'PENDING',  -- PENDING / VALID / REJECTED / APPLIED
    RejectReason     VARCHAR(500) NULL,
    LoadedAt         DATETIME2    NOT NULL DEFAULT SYSDATETIME()
);

-- Change log: one row per changed column
CREATE TABLE audit.ChangeLog (
    ChangeID     BIGINT IDENTITY(1,1) PRIMARY KEY,
    BatchID      INT          NOT NULL REFERENCES audit.BatchRun(BatchID),
    OrderID      INT          NOT NULL,
    ColumnName   VARCHAR(100) NOT NULL,
    OldValue     VARCHAR(500) NULL,
    NewValue     VARCHAR(500) NULL,
    ChangedAt    DATETIME2    NOT NULL DEFAULT SYSDATETIME(),
    ChangedBy    VARCHAR(100) NOT NULL DEFAULT SUSER_SNAME()
);
GO
