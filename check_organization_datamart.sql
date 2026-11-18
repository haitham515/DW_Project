/* =====================================================================
   DimOrganization - SCD test
   Run the parts ONE AT A TIME (select the part, then F5).
   ===================================================================== */

/* ---------------------------------------------------------------------
   PART A - After the FIRST run of 20_DimOrganization.dtsx
   Expected: 14 rows, all IsCurrent = 1, StartDate = 2010-07-01,
             EndDate = NULL, only "AdventureWorks Cycle" without parent.
   --------------------------------------------------------------------- */


USE LightFinanceDW;
SELECT o.OrganizationKey, o.OrganizationAlternateKey, o.OrganizationName,
       o.PercentageOfOwnership, c.CurrencyAlternateKey AS Currency,
       p.OrganizationName AS ParentName,
       o.StartDate, o.EndDate, o.IsCurrent
FROM dbo.DimOrganization o
LEFT JOIN dbo.DimCurrency     c ON c.CurrencyKey     = o.CurrencyKey
LEFT JOIN dbo.DimOrganization p ON p.OrganizationKey = o.ParentOrganizationKey
ORDER BY o.OrganizationAlternateKey, o.OrganizationKey;
GO

/* ---------------------------------------------------------------------
   PART B - Simulate two business changes IN THE SOURCE
     - Type 2: the group buys the remaining 25% of the Canadian Division
     - Type 1: "Central Division" is renamed "Central Region"
   (keys 8 and 5 are the source keys of these two organizations)
   Then run 20_DimOrganization.dtsx AGAIN.
   --------------------------------------------------------------------- */

/*
USE AdventureWorksDW2025;
UPDATE dbo.DimOrganization SET PercentageOfOwnership = N'1'
WHERE OrganizationKey = 8;               -- Canadian Division: .75 -> 1
UPDATE dbo.DimOrganization SET OrganizationName = N'Central Region'
WHERE OrganizationKey = 5;               -- Central Division -> Central Region
GO
*/

/* ---------------------------------------------------------------------
   PART C - After the SECOND run
   Expected: 15 rows.
     - Canadian Division: 2 rows
         0.7500, StartDate 2010-07-01, EndDate = date of the run, IsCurrent 0
         1.0000, StartDate = date of the run, EndDate NULL,       IsCurrent 1
     - Central: still 1 row, same key, name now "Central Region"
   --------------------------------------------------------------------- */
/*
USE LightFinanceDW;
SELECT o.OrganizationKey, o.OrganizationAlternateKey, o.OrganizationName,
       o.PercentageOfOwnership, o.StartDate, o.EndDate, o.IsCurrent
FROM dbo.DimOrganization o
WHERE o.OrganizationAlternateKey IN (5, 8)
ORDER BY o.OrganizationAlternateKey, o.OrganizationKey;

SELECT COUNT(*) AS NbRows,
       SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS NbCurrent
FROM dbo.DimOrganization;               -- expected: 15 rows, 14 current
GO
*/

/* ---------------------------------------------------------------------
   PART D - Restore the source to its original values.
   WARNING: if you re-run the package after this, the SCD will see a new
   change (1 -> .75) and create a THIRD version of Canada. Restore the
   source only when you also reset the datamart (e.g. before recording
   the demo video).
   --------------------------------------------------------------------- */
/*
USE AdventureWorksDW2025;
UPDATE dbo.DimOrganization SET PercentageOfOwnership = N'.75'
WHERE OrganizationKey = 8;
UPDATE dbo.DimOrganization SET OrganizationName = N'Central Division'
WHERE OrganizationKey = 5;
GO
*/