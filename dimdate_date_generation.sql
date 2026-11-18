/* =====================================================================
   LightFinanceDW - DimDate generation
   ---------------------------------------------------------------------
   Requirement: "Génération des données de la dimension Temps à l'aide
   d'un code SQL à partir d'une date début à préciser".

   Chosen dates (justification) - aligned on the FISCAL calendar:
     - The finance department reports by fiscal year (July -> June).
     - Facts run from 2010-12-29 to 2013-12-28, i.e. fiscal years
       FY2010 to FY2013.
     - Start 2010-07-01 = first day of FY2010.
     - End   2014-06-30 = last day of FY2013.
     -> every fiscal year in the calendar is complete, and the 6 months
        after the last fact (Jan-Jun 2014) leave room for the delta-load test.
   Both are parameters: the calendar can be extended without changing code.

   Fiscal calendar (copied from AdventureWorksDW2025.dbo.DimDate):
     - Fiscal year starts on July 1st and is named after the calendar
       year it starts in (FY2012 = 2012-07-01 .. 2013-06-30).
     - Fiscal quarters: Jul-Sep = 1, Oct-Dec = 2, Jan-Mar = 3, Apr-Jun = 4
     - Fiscal semesters: Jul-Dec = 1, Jan-Jun = 2

   Day/month names are written explicitly (not DATENAME) so the result
   does not depend on the language of the SQL Server session.
   The procedure only inserts dates that are missing: it can be run again.
   ===================================================================== */

USE LightFinanceDW;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GenerateDimDate
    @StartDate date,
    @EndDate   date
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 7;   -- Sunday = day 1, as in AdventureWorksDW (only for this procedure)

    IF @StartDate > @EndDate
    BEGIN
        RAISERROR(N'@StartDate must be before @EndDate.', 16, 1);
        RETURN;
    END;

    DECLARE @d date = @StartDate;
    DECLARE @m int, @dw int;

    -- One loop turn = one day = one row
    WHILE @d <= @EndDate
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.DimDate WHERE FullDateAlternateKey = @d)
        BEGIN
            SET @m  = MONTH(@d);
            SET @dw = DATEPART(weekday, @d);   -- 1 = Sunday ... 7 = Saturday

            INSERT INTO dbo.DimDate (
                DateKey, FullDateAlternateKey,
                DayNumberOfWeek, EnglishDayNameOfWeek, SpanishDayNameOfWeek, FrenchDayNameOfWeek,
                DayNumberOfMonth, DayNumberOfYear, WeekNumberOfYear,
                EnglishMonthName, SpanishMonthName, FrenchMonthName,
                MonthNumberOfYear, CalendarQuarter, CalendarYear, CalendarSemester,
                FiscalQuarter, FiscalYear, FiscalSemester)
            VALUES (
                YEAR(@d) * 10000 + @m * 100 + DAY(@d),                 -- DateKey YYYYMMDD
                @d,
                @dw,
                CHOOSE(@dw, N'Sunday', N'Monday', N'Tuesday', N'Wednesday',
                            N'Thursday', N'Friday', N'Saturday'),
                CHOOSE(@dw, N'Domingo', N'Lunes', N'Martes', N'Miércoles',
                            N'Jueves', N'Viernes', N'Sábado'),
                CHOOSE(@dw, N'Dimanche', N'Lundi', N'Mardi', N'Mercredi',
                            N'Jeudi', N'Vendredi', N'Samedi'),
                DAY(@d),
                DATEPART(dayofyear, @d),
                DATEPART(week, @d),
                CHOOSE(@m, N'January', N'February', N'March', N'April', N'May', N'June',
                           N'July', N'August', N'September', N'October', N'November', N'December'),
                CHOOSE(@m, N'Enero', N'Febrero', N'Marzo', N'Abril', N'Mayo', N'Junio',
                           N'Julio', N'Agosto', N'Septiembre', N'Octubre', N'Noviembre', N'Diciembre'),
                CHOOSE(@m, N'Janvier', N'Février', N'Mars', N'Avril', N'Mai', N'Juin',
                           N'Juillet', N'Août', N'Septembre', N'Octobre', N'Novembre', N'Décembre'),
                @m,
                DATEPART(quarter, @d),
                YEAR(@d),
                CASE WHEN @m <= 6 THEN 1 ELSE 2 END,                    -- CalendarSemester
                ((@m + 5) % 12) / 3 + 1,                                -- FiscalQuarter (Jul=1)
                CASE WHEN @m >= 7 THEN YEAR(@d) ELSE YEAR(@d) - 1 END,  -- FiscalYear
                CASE WHEN @m >= 7 THEN 1 ELSE 2 END                     -- FiscalSemester
            );
        END;

        SET @d = DATEADD(day, 1, @d);
    END;
END;
GO

/* ---------------------------------------------------------------------
   Run the generation
   --------------------------------------------------------------------- */
EXEC dbo.usp_GenerateDimDate @StartDate = '2010-07-01', @EndDate = '2014-06-30';
GO

/* ---------------------------------------------------------------------
   Check 1: expected 1461 rows, from 20100701 to 20140630
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS NbRows, MIN(DateKey) AS FirstDate, MAX(DateKey) AS LastDate
FROM dbo.DimDate;

/* ---------------------------------------------------------------------
   Check 2: fiscal rule on the 1st of each month of 2012
            (must match the AdventureWorksDW2025 result)
   --------------------------------------------------------------------- */
SELECT FullDateAlternateKey, CalendarYear, FiscalYear, FiscalQuarter, FiscalSemester
FROM dbo.DimDate
WHERE DayNumberOfMonth = 1 AND CalendarYear = 2012
ORDER BY FullDateAlternateKey;

/* ---------------------------------------------------------------------
   Check 3: compare EVERY column with AdventureWorksDW2025.dbo.DimDate
            on the dates both tables contain.
            Expected result: 0 rows (= identical calendars).
   --------------------------------------------------------------------- */
SELECT d.DateKey, d.FullDateAlternateKey, d.DayNumberOfWeek, d.EnglishDayNameOfWeek,
       d.SpanishDayNameOfWeek, d.FrenchDayNameOfWeek, d.DayNumberOfMonth, d.DayNumberOfYear,
       d.WeekNumberOfYear, d.EnglishMonthName, d.SpanishMonthName, d.FrenchMonthName,
       d.MonthNumberOfYear, d.CalendarQuarter, d.CalendarYear, d.CalendarSemester,
       d.FiscalQuarter, d.FiscalYear, d.FiscalSemester
FROM dbo.DimDate d
WHERE d.FullDateAlternateKey IN (SELECT FullDateAlternateKey FROM AdventureWorksDW2025.dbo.DimDate)
EXCEPT
SELECT a.DateKey, a.FullDateAlternateKey, a.DayNumberOfWeek,
       a.EnglishDayNameOfWeek COLLATE DATABASE_DEFAULT,
       a.SpanishDayNameOfWeek COLLATE DATABASE_DEFAULT,
       a.FrenchDayNameOfWeek  COLLATE DATABASE_DEFAULT,
       a.DayNumberOfMonth, a.DayNumberOfYear, a.WeekNumberOfYear,
       a.EnglishMonthName COLLATE DATABASE_DEFAULT,
       a.SpanishMonthName COLLATE DATABASE_DEFAULT,
       a.FrenchMonthName  COLLATE DATABASE_DEFAULT,
       a.MonthNumberOfYear, a.CalendarQuarter, a.CalendarYear, a.CalendarSemester,
       a.FiscalQuarter, a.FiscalYear, a.FiscalSemester
FROM AdventureWorksDW2025.dbo.DimDate a;
GO