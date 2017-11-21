/* Вспомогательные функции
 Функция генерирует непрерывный диапазон целочисленных значений.*/
IF OBJECT_ID('dbo.udf_getRangeNumbers') IS NOT NULL
  DROP FUNCTION dbo.udf_getRangeNumbers;
GO
CREATE FUNCTION dbo.udf_getRangeNumbers (@min int, @max int)
RETURNS TABLE

AS
  RETURN
  WITH rangeNumbers (n)
  AS
  (SELECT
    @min
  UNION ALL
  SELECT
    n + 1
  FROM rangeNumbers
  WHERE n < @max)
  SELECT
    n
  FROM rangeNumbers
GO
/*Представление для оборачивания вызова NEWID() в функции.*/
IF OBJECT_ID('wv_getNewID') IS NOT NULL
  DROP VIEW dbo.wv_getNewID;
GO
CREATE VIEW dbo.wv_getNewID
AS
SELECT
  NEWID() AS [NewID];
GO
/*Представление для оборачивания вызова RAND() в функции.*/
IF OBJECT_ID('wv_getRand') IS NOT NULL
  DROP VIEW wv_getRand;
GO
CREATE VIEW wv_getRand
AS
SELECT
  RAND() AS [Rand];
GO
/*Генерирует строку случайных символов указанный в параметре @length длины.*/
IF OBJECT_ID('dbo.udf_getRandomString') IS NOT NULL
  DROP FUNCTION dbo.udf_getRandomString;
GO
CREATE FUNCTION dbo.udf_getRandomString (@length int = 10)
RETURNS nvarchar(max)
AS
BEGIN
  DECLARE @min int = 1072,
          @max int = 1103,
          @counter int = 0,
          @resultString nvarchar(max) = N'',
          @ncharCode int;
  DECLARE @numbers TABLE (
    n int NOT NULL
  )
  INSERT INTO @numbers
    SELECT
      n
    FROM dbo.udf_getRangeNumbers(@min, @max)

  WHILE (@counter < @length)
  BEGIN
    SELECT TOP 1
      @ncharCode = n
    FROM @numbers
    ORDER BY (SELECT
      *
    FROM wv_getNewID)
    SET @resultString = @resultString + NCHAR(@ncharCode)
    SET @counter = @counter + 1;
  END
  RETURN @resultString
END
GO
/*Генерирует строку случайных цифр указанный в параметре @length длины.*/
IF OBJECT_ID('dbo.udf_getRandomNumberString') IS NOT NULL
  DROP FUNCTION dbo.udf_getRandomNumberString;
GO
CREATE FUNCTION dbo.udf_getRandomNumberString (@length int = 10)
RETURNS nvarchar(max)
AS
BEGIN
  DECLARE @min int = 0,
          @max int = 9,
          @counter int = 0,
          @resultString nvarchar(max) = N'';

  WHILE (@counter < @length)
  BEGIN

    SET @resultString = @resultString + CAST(dbo.udf_getRandomNumberFromRange(@min, @max) AS nvarchar(1))

    SET @counter = @counter + 1;
  END

  RETURN @resultString;
END
GO
/*Возвращает случайное число из указанного диапозона чисел*/
IF OBJECT_ID('dbo.udf_getRandomNumberFromRange') IS NOT NULL
  DROP FUNCTION dbo.udf_getRandomNumberFromRange;
GO

CREATE FUNCTION dbo.udf_getRandomNumberFromRange (@min int, @max int)
RETURNS int
AS
BEGIN
  DECLARE @rnd float
  SELECT
    @rnd = rand
  FROM dbo.wv_getRand
  RETURN @min + CAST((@rnd * (@max - @min + 1)) AS int);
END
GO
/*Возвращает случайную строку случайной длины в диапозоне от @minLen до @maxLen.*/
IF OBJECT_ID('dbo.udf_getRandomStringVarLen') IS NOT NULL
  DROP FUNCTION dbo.udf_getRandomStringVarLen;
GO

CREATE FUNCTION dbo.udf_getRandomStringVarLen (@minLen int, @maxLen int)
RETURNS nvarchar(max)
AS
BEGIN
  DECLARE @randomLen int;
  SET @randomLen = dbo.udf_getRandomNumberFromRange(@minLen, @maxLen)
  RETURN dbo.udf_getRandomString(@randomLen);
END
GO
