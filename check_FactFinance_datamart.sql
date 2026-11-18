/* =====================================================================
   FactFinance - checks and delta test
   Run ONE part at a time (comment the others, or select the part + F5).
   ===================================================================== */

/* ---------------------------------------------------------------------
   PART A - After the FIRST run of FactFinance.dtsx
   --------------------------------------------------------------------- */

/*
USE LightFinanceDW;

-- A1. Row counts: both numbers must be equal (expected: 39409)
SELECT (SELECT COUNT(*) FROM dbo.FactFinance)                      AS Datamart,
       (SELECT COUNT(*) FROM AdventureWorksDW2025.dbo.FactFinance) AS Source;

-- A2. Totals per scenario: the Difference column must be 0 on every row.
--     This proves no fact was lost by the joins of the source query.
SELECT src.ScenarioName,
       src.NbRows   AS Source_Rows,  dm.NbRows   AS Datamart_Rows,
       src.Total    AS Source_Total, dm.Total    AS Datamart_Total,
       src.Total - dm.Total AS Difference
FROM (SELECT s.ScenarioName, COUNT(*) AS NbRows, SUM(f.Amount) AS Total
      FROM AdventureWorksDW2025.dbo.FactFinance f
      JOIN AdventureWorksDW2025.dbo.DimScenario s ON s.ScenarioKey = f.ScenarioKey
      GROUP BY s.ScenarioName) src
JOIN (SELECT s.ScenarioName, COUNT(*) AS NbRows, SUM(f.Amount) AS Total
      FROM dbo.FactFinance f
      JOIN dbo.DimScenario s ON s.ScenarioKey = f.ScenarioKey
      GROUP BY s.ScenarioName) dm
  ON dm.ScenarioName = src.ScenarioName;

-- A3. Facts per organization version (Canada = business key 8):
--     every Canada fact must be on the version valid at the fact's date
SELECT o.OrganizationKey, o.OrganizationName, o.PercentageOfOwnership,
       o.StartDate, o.EndDate, COUNT(f.FinanceKey) AS NbFacts
FROM dbo.DimOrganization o
LEFT JOIN dbo.FactFinance f ON f.OrganizationKey = o.OrganizationKey
WHERE o.OrganizationAlternateKey = 8
GROUP BY o.OrganizationKey, o.OrganizationName, o.PercentageOfOwnership,
         o.StartDate, o.EndDate;
GO
*/

/* ---------------------------------------------------------------------
   PART B - Delta test: add new facts IN THE SOURCE
   Copies the facts of the last date (2013-12-28) to a new date
   (2014-01-28), as if January 2014 had just been closed.
   Then run FactFinance.dtsx AGAIN.
   --------------------------------------------------------------------- */

/*
USE AdventureWorksDW2025;
INSERT INTO dbo.FactFinance
       (DateKey, OrganizationKey, DepartmentGroupKey, ScenarioKey, AccountKey, Amount, [Date])
SELECT 20140128, OrganizationKey, DepartmentGroupKey, ScenarioKey, AccountKey, Amount, '20140128'
FROM dbo.FactFinance
WHERE DateKey = 20131228;

SELECT COUNT(*) AS NewSourceRows          -- note this number
FROM dbo.FactFinance WHERE DateKey = 20140128;
GO
*/

/* ---------------------------------------------------------------------
   PART C - After the SECOND run
   Expected: NewDatamartRows = NewSourceRows (part B),
             and only those rows were loaded (nothing loaded twice).
   --------------------------------------------------------------------- */

/*
USE LightFinanceDW;
SELECT (SELECT COUNT(*) FROM dbo.FactFinance WHERE DateKey = 20140128) AS NewDatamartRows,
       (SELECT COUNT(*) FROM dbo.FactFinance)                          AS TotalDatamart,
       (SELECT COUNT(*) FROM AdventureWorksDW2025.dbo.FactFinance)     AS TotalSource;
GO
*/

/* ---------------------------------------------------------------------
   PART D - Clean up the delta test (later, before the final reset):
   removes the test facts from the datamart AND from the source.
   --------------------------------------------------------------------- */

/*
DELETE FROM LightFinanceDW.dbo.FactFinance       WHERE DateKey = 20140128;
DELETE FROM AdventureWorksDW2025.dbo.FactFinance WHERE DateKey = 20140128;
GO
*/