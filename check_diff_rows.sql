/* =====================================================================
   Checks before building the SSIS packages (read-only)
   ===================================================================== */
USE LightFinanceDW;
GO

/* ---------------------------------------------------------------------
   A. DimDate: how many rows differ from AdventureWorksDW2025, per column.
      Every Diff_ column should be 0. Send the result if one is not.
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS ComparedRows,
  SUM(CASE WHEN d.DateKey           <> a.DateKey           THEN 1 ELSE 0 END) AS Diff_DateKey,
  SUM(CASE WHEN d.DayNumberOfWeek   <> a.DayNumberOfWeek   THEN 1 ELSE 0 END) AS Diff_DayNumberOfWeek,
  SUM(CASE WHEN d.EnglishDayNameOfWeek <> a.EnglishDayNameOfWeek COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END) AS Diff_EnglishDay,
  SUM(CASE WHEN d.SpanishDayNameOfWeek <> a.SpanishDayNameOfWeek COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END) AS Diff_SpanishDay,
  SUM(CASE WHEN d.FrenchDayNameOfWeek  <> a.FrenchDayNameOfWeek  COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END) AS Diff_FrenchDay,
  SUM(CASE WHEN d.DayNumberOfMonth  <> a.DayNumberOfMonth  THEN 1 ELSE 0 END) AS Diff_DayNumberOfMonth,
  SUM(CASE WHEN d.DayNumberOfYear   <> a.DayNumberOfYear   THEN 1 ELSE 0 END) AS Diff_DayNumberOfYear,
  SUM(CASE WHEN d.WeekNumberOfYear  <> a.WeekNumberOfYear  THEN 1 ELSE 0 END) AS Diff_WeekNumberOfYear,
  SUM(CASE WHEN d.EnglishMonthName  <> a.EnglishMonthName  COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END) AS Diff_EnglishMonth,
  SUM(CASE WHEN d.SpanishMonthName  <> a.SpanishMonthName  COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END) AS Diff_SpanishMonth,
  SUM(CASE WHEN d.FrenchMonthName   <> a.FrenchMonthName   COLLATE DATABASE_DEFAULT THEN 1 ELSE 0 END) AS Diff_FrenchMonth,
  SUM(CASE WHEN d.MonthNumberOfYear <> a.MonthNumberOfYear THEN 1 ELSE 0 END) AS Diff_MonthNumber,
  SUM(CASE WHEN d.CalendarQuarter   <> a.CalendarQuarter   THEN 1 ELSE 0 END) AS Diff_CalendarQuarter,
  SUM(CASE WHEN d.CalendarYear      <> a.CalendarYear      THEN 1 ELSE 0 END) AS Diff_CalendarYear,
  SUM(CASE WHEN d.CalendarSemester  <> a.CalendarSemester  THEN 1 ELSE 0 END) AS Diff_CalendarSemester,
  SUM(CASE WHEN d.FiscalQuarter     <> a.FiscalQuarter     THEN 1 ELSE 0 END) AS Diff_FiscalQuarter,
  SUM(CASE WHEN d.FiscalYear        <> a.FiscalYear        THEN 1 ELSE 0 END) AS Diff_FiscalYear,
  SUM(CASE WHEN d.FiscalSemester    <> a.FiscalSemester    THEN 1 ELSE 0 END) AS Diff_FiscalSemester
FROM dbo.DimDate d
JOIN AdventureWorksDW2025.dbo.DimDate a
  ON a.FullDateAlternateKey = d.FullDateAlternateKey;
GO

/* ---------------------------------------------------------------------
   B. DimDepartmentGroup: do the OLTP group names match the DW names?
      The facts (from AdventureWorksDW2025) will be matched to our
      DimDepartmentGroup BY NAME, so the names must be identical.
   --------------------------------------------------------------------- */
-- B1. Names in the DW but not in the OLTP -> expected: only 'Corporate'
SELECT DepartmentGroupName AS InDW_NotInOLTP
FROM AdventureWorksDW2025.dbo.DimDepartmentGroup
EXCEPT
SELECT DISTINCT GroupName
FROM AdventureWorks2025.HumanResources.Department;

-- B2. Names in the OLTP but not in the DW -> expected: 0 rows
SELECT DISTINCT GroupName AS InOLTP_NotInDW
FROM AdventureWorks2025.HumanResources.Department
EXCEPT
SELECT DepartmentGroupName
FROM AdventureWorksDW2025.dbo.DimDepartmentGroup;
GO