-- RetailUZ demo database (W13 seed). Idempotent: safe to re-run.
IF DB_ID('RetailUZ') IS NULL CREATE DATABASE RetailUZ;
GO
USE RetailUZ;
GO
IF OBJECT_ID('dbo.Sales') IS NULL
BEGIN
    CREATE TABLE dbo.Region (
        RegionID   INT PRIMARY KEY,
        RegionName NVARCHAR(50) NOT NULL
    );
    CREATE TABLE dbo.Store (
        StoreID   INT PRIMARY KEY,
        StoreName NVARCHAR(100) NOT NULL,
        RegionID  INT NOT NULL REFERENCES dbo.Region(RegionID)
    );
    CREATE TABLE dbo.Product (
        ProductID   INT PRIMARY KEY,
        ProductName NVARCHAR(100) NOT NULL,
        Category    NVARCHAR(50)  NOT NULL,
        UnitPrice   DECIMAL(12,2) NOT NULL   -- UZS
    );
    CREATE TABLE dbo.Sales (
        SaleID    INT IDENTITY PRIMARY KEY,
        SaleDate  DATE NOT NULL,
        StoreID   INT NOT NULL REFERENCES dbo.Store(StoreID),
        ProductID INT NOT NULL REFERENCES dbo.Product(ProductID),
        Qty       INT NOT NULL,
        Amount    DECIMAL(14,2) NOT NULL
    );

    INSERT dbo.Region VALUES
        (1, N'Toshkent'), (2, N'Samarqand'), (3, N'Buxoro'), (4, N'Farg''ona'), (5, N'Andijon');

    INSERT dbo.Store VALUES
        (1, N'Chilonzor Market', 1), (2, N'Yunusobod Market', 1), (3, N'Registon Savdo', 2),
        (4, N'Buxoro Markaz', 3),    (5, N'Farg''ona Bozor', 4),   (6, N'Andijon City', 5);

    INSERT dbo.Product VALUES
        (1,  N'Non',          N'Oziq-ovqat',   4000),
        (2,  N'Sut 1L',       N'Oziq-ovqat',  12000),
        (3,  N'Guruch 1kg',   N'Oziq-ovqat',  18000),
        (4,  N'Choy 100g',    N'Ichimlik',    15000),
        (5,  N'Coca-Cola 1.5L',N'Ichimlik',   14000),
        (6,  N'Sovun',        N'Gigiyena',     9000),
        (7,  N'Shampun',      N'Gigiyena',    35000),
        (8,  N'Daftar',       N'Kanselyariya', 6000),
        (9,  N'Ruchka',       N'Kanselyariya', 3000),
        (10, N'Paxta yog''i 1L', N'Oziq-ovqat', 28000);

    -- ~2000 deterministic pseudo-random sales across 2026
    ;WITH n AS (
        SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    INSERT dbo.Sales (SaleDate, StoreID, ProductID, Qty, Amount)
    SELECT d.SaleDate, d.StoreID, d.ProductID, d.Qty, d.Qty * p.UnitPrice
    FROM (
        SELECT DATEADD(DAY, (i * 37) % 300, '2026-01-01') AS SaleDate,
               (i * 7)  % 6  + 1 AS StoreID,
               (i * 13) % 10 + 1 AS ProductID,
               (i * 11) % 5  + 1 AS Qty
        FROM n
    ) d
    JOIN dbo.Product p ON p.ProductID = d.ProductID;
END
GO
SELECT COUNT(*) AS SalesRows FROM RetailUZ.dbo.Sales;
GO
