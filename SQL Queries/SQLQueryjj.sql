SELECT * FROM dbo.AuditLog ;





DELETE FROM dbo.FactSales;
DELETE FROM dbo.RejectedRecords;
DELETE FROM dbo.AuditLog;
DELETE FROM dbo.DimCustomer;
DELETE FROM dbo.DimProduct;
DELETE FROM dbo.DimStore;
DELETE FROM stg.Customer;
DELETE FROM stg.Product;
DELETE FROM stg.Store;
DELETE FROM stg.Sales;
GO

DBCC CHECKIDENT ('dbo.FactSales', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimCustomer', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimProduct', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimStore', RESEED, 0);
DBCC CHECKIDENT ('dbo.AuditLog', RESEED, 0);
GO



SELECT * FROM dbo.FileImports;



DELETE FROM dbo.FactSales;
DELETE FROM dbo.RejectedRecords;
DELETE FROM dbo.AuditLog;
DELETE FROM dbo.FileImports;
DELETE FROM dbo.DimCustomer;
DELETE FROM dbo.DimProduct;
DELETE FROM dbo.DimStore;
DELETE FROM stg.Customer;
DELETE FROM stg.Product;
DELETE FROM stg.Store;
DELETE FROM stg.Sales;


SELECT * FROM dbo.FileImports ORDER BY FileImportID DESC;

select * from AuditLog;