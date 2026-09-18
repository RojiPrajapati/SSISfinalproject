/* ============================================================
   RetailDW - Database and Table Creation Script
   Run this ENTIRE script in SSMS (connected to your SQL Server instance)
   ============================================================ */

-- ============================================================
-- STEP 1: Create the Database
-- ============================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'RetailDW')
BEGIN
    CREATE DATABASE RetailDW;
END
GO

USE RetailDW;
GO

-- ============================================================
-- STEP 2: Drop existing tables if re-running this script (dev convenience)
-- Order matters because of foreign keys: drop Fact before Dims
-- ============================================================
IF OBJECT_ID('dbo.FactSales', 'U') IS NOT NULL DROP TABLE dbo.FactSales;
IF OBJECT_ID('dbo.DimCustomer', 'U') IS NOT NULL DROP TABLE dbo.DimCustomer;
IF OBJECT_ID('dbo.DimProduct', 'U') IS NOT NULL DROP TABLE dbo.DimProduct;
IF OBJECT_ID('dbo.DimStore', 'U') IS NOT NULL DROP TABLE dbo.DimStore;
IF OBJECT_ID('dbo.FileImports', 'U') IS NOT NULL DROP TABLE dbo.FileImports;
IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL DROP TABLE dbo.AuditLog;
IF OBJECT_ID('dbo.RejectedRecords', 'U') IS NOT NULL DROP TABLE dbo.RejectedRecords;
IF OBJECT_ID('stg.Customer', 'U') IS NOT NULL DROP TABLE stg.Customer;
IF OBJECT_ID('stg.Product', 'U') IS NOT NULL DROP TABLE stg.Product;
IF OBJECT_ID('stg.Store', 'U') IS NOT NULL DROP TABLE stg.Store;
IF OBJECT_ID('stg.Sales', 'U') IS NOT NULL DROP TABLE stg.Sales;
GO

-- ============================================================
-- STEP 2b: Staging Schema and Staging Tables
-- Staging tables hold raw data exactly as it arrives from the flat files,
-- BEFORE any validation/transformation. Everything is loaded as loosely-typed
-- (mostly VARCHAR) so a bad row (e.g. text in a numeric column) doesn't
-- fail the whole Data Flow at the source - you can then validate/cast in
-- SSIS or via SQL against the staging table itself. Each load run appends
-- to staging, and staging is typically truncated before each new load.
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg');
END
GO

-- stg.Customer - raw Customers.csv, one row per source row
CREATE TABLE stg.Customer (
    StgCustomerID    INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID       VARCHAR(50)   NULL,
    CustomerName     VARCHAR(200)  NULL,
    Email            VARCHAR(200)  NULL,
    City             VARCHAR(100)  NULL,
    State            VARCHAR(100)  NULL,
    SourceFileName   VARCHAR(255)  NULL,
    LoadedDate       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- stg.Product - raw Products.csv, one row per source row
CREATE TABLE stg.Product (
    StgProductID     INT IDENTITY(1,1) PRIMARY KEY,
    ProductID        VARCHAR(50)   NULL,
    ProductName      VARCHAR(200)  NULL,
    Category         VARCHAR(100)  NULL,
    Price            VARCHAR(50)   NULL,   -- kept as VARCHAR so non-numeric junk doesn't break the load
    SourceFileName   VARCHAR(255)  NULL,
    LoadedDate       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- stg.Store - raw Stores.csv, one row per source row
CREATE TABLE stg.Store (
    StgStoreID       INT IDENTITY(1,1) PRIMARY KEY,
    StoreID          VARCHAR(50)   NULL,
    StoreName        VARCHAR(200)  NULL,
    City             VARCHAR(100)  NULL,
    State            VARCHAR(100)  NULL,
    SourceFileName   VARCHAR(255)  NULL,
    LoadedDate       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- stg.Sales - raw Sales_YYYYMMDD.csv, one row per source row
CREATE TABLE stg.Sales (
    StgSalesID       INT IDENTITY(1,1) PRIMARY KEY,
    SaleID           VARCHAR(50)   NULL,
    SaleDate         VARCHAR(50)   NULL,   -- kept as VARCHAR so invalid dates don't break the load
    CustomerID       VARCHAR(50)   NULL,
    ProductID        VARCHAR(50)   NULL,
    StoreID          VARCHAR(50)   NULL,
    Quantity         VARCHAR(50)   NULL,
    UnitPrice        VARCHAR(50)   NULL,
    SourceFileName   VARCHAR(255)  NULL,
    LoadedDate       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- STEP 3: Dimension Tables
-- ============================================================

-- DimCustomer
CREATE TABLE dbo.DimCustomer (
    CustomerKey     INT IDENTITY(1,1) PRIMARY KEY,   -- warehouse-generated key
    CustomerID      VARCHAR(20)   NOT NULL,           -- business key from source file
    CustomerName    VARCHAR(200)  NOT NULL,
    Email           VARCHAR(200)  NULL,
    City            VARCHAR(100)  NULL,
    State           VARCHAR(100)  NULL,
    CreatedDate     DATETIME      NOT NULL DEFAULT GETDATE(),
    ModifiedDate    DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_DimCustomer_CustomerID UNIQUE (CustomerID)
);
GO

-- DimProduct
CREATE TABLE dbo.DimProduct (
    ProductKey      INT IDENTITY(1,1) PRIMARY KEY,
    ProductID       VARCHAR(20)   NOT NULL,
    ProductName     VARCHAR(200)  NOT NULL,
    Category        VARCHAR(100)  NULL,
    Price           DECIMAL(18,2) NOT NULL,
    CreatedDate     DATETIME      NOT NULL DEFAULT GETDATE(),
    ModifiedDate    DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_DimProduct_ProductID UNIQUE (ProductID)
);
GO

-- DimStore
CREATE TABLE dbo.DimStore (
    StoreKey        INT IDENTITY(1,1) PRIMARY KEY,
    StoreID         VARCHAR(20)   NOT NULL,
    StoreName       VARCHAR(200)  NOT NULL,
    City            VARCHAR(100)  NULL,
    State           VARCHAR(100)  NULL,
    CONSTRAINT UQ_DimStore_StoreID UNIQUE (StoreID)
);
GO

-- ============================================================
-- STEP 4: Fact Table
-- ============================================================

-- FactSales
CREATE TABLE dbo.FactSales (
    SalesKey        INT IDENTITY(1,1) PRIMARY KEY,
    SaleID          VARCHAR(20)   NOT NULL,           -- business key, used for duplicate prevention
    SaleDate        DATE          NOT NULL,
    CustomerKey     INT           NOT NULL,
    ProductKey      INT           NOT NULL,
    StoreKey        INT           NOT NULL,
    Quantity        INT           NOT NULL,
    UnitPrice       DECIMAL(18,2) NOT NULL,
    TotalAmount     DECIMAL(18,2) NOT NULL,           -- Quantity * UnitPrice, calculated in SSIS
    LoadDate        DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT UQ_FactSales_SaleID UNIQUE (SaleID),   -- enforces no duplicate transactions
    CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerKey) REFERENCES dbo.DimCustomer(CustomerKey),
    CONSTRAINT FK_FactSales_Product  FOREIGN KEY (ProductKey)  REFERENCES dbo.DimProduct(ProductKey),
    CONSTRAINT FK_FactSales_Store    FOREIGN KEY (StoreKey)    REFERENCES dbo.DimStore(StoreKey)
);
GO

-- Helpful index for lookups/joins during ETL and reporting
CREATE INDEX IX_FactSales_SaleDate ON dbo.FactSales(SaleDate);
CREATE INDEX IX_FactSales_CustomerKey ON dbo.FactSales(CustomerKey);
CREATE INDEX IX_FactSales_ProductKey ON dbo.FactSales(ProductKey);
CREATE INDEX IX_FactSales_StoreKey ON dbo.FactSales(StoreKey);
GO

-- ============================================================
-- STEP 5: File Tracking Table
-- ============================================================

CREATE TABLE dbo.FileImports (
    FileImportID      INT IDENTITY(1,1) PRIMARY KEY,
    FileName          VARCHAR(255)  NOT NULL,
    ArchivePath       VARCHAR(500)  NULL,             -- final location: Archive or Error folder
    FileImportStatus  VARCHAR(50)   NOT NULL,         -- 'Received', 'Successfully Loaded', 'Failed'
    CreatedDate       DATETIME      NOT NULL DEFAULT GETDATE(),
    UpdatedDate       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- STEP 6: Audit Table
-- ============================================================

CREATE TABLE dbo.AuditLog (
    AuditID           INT IDENTITY(1,1) PRIMARY KEY,
    PackageName       VARCHAR(200)  NOT NULL,
    SourceFile        VARCHAR(255)  NULL,
    StartTime         DATETIME      NOT NULL,
    EndTime           DATETIME      NULL,
    Status            VARCHAR(50)   NOT NULL DEFAULT 'Running',  -- Running, Success, Failed
    RecordsRead       INT           NULL,
    RecordsInserted   INT           NULL,
    RecordsRejected   INT           NULL,
    ErrorMessage      VARCHAR(MAX)  NULL
);
GO

-- ============================================================
-- STEP 7: Rejected Records Table
-- ============================================================

CREATE TABLE dbo.RejectedRecords (
    RejectID          INT IDENTITY(1,1) PRIMARY KEY,
    SourceFile        VARCHAR(255)  NOT NULL,
    RecordKey         VARCHAR(200)  NULL,             -- e.g. CustomerID / ProductID / SaleID of the bad row
    ErrorReason       VARCHAR(500)  NOT NULL,
    SourceTable      VARCHAR(50)       NULL,  
    ErrorDate         DATETIME      NOT NULL DEFAULT GETDATE(),
    RawData           VARCHAR(MAX)  NULL              -- optional: store the full offending row as text
);
GO

-- ============================================================
-- Done. Quick sanity check: list all tables created
-- ============================================================
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO