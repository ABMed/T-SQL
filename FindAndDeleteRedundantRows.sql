USE tempdb;
GO
-- Для теста
IF OBJECT_ID('dbo.AutoParts') IS NOT NULL
  DROP TABLE dbo.AutoParts;

CREATE TABLE dbo.AutoParts (
  code_cat int NOT NULL,
  class_cat varchar(1000)
);
GO

INSERT INTO dbo.AutoParts (code_cat, class_cat)
  VALUES (1, 'Запчасть крыло левое'),
  (1, 'Запчасть крыло'),                              -- избыточная запись
  (1, 'Запчасть крыло Mazda'),
  (2, 'Фонарь правый Mazda 626'),
  (2, 'Фонарь'),                                               -- избыточная запись
  (2, 'Фонарь Mazda фонарь правый'),              -- избыточная запись
  (2, 'Запчасть'),
  (2, 'Запч Mazda'),
  (2, 'Фонарь правый Mazda 626');       -- избыточная запись
GO

-- Разбивает строку @inputString в таблицу с одним столбцом по разделителю @delimeter
IF OBJECT_ID('dbo.SplitStrings') IS NOT NULL
  DROP FUNCTION dbo.SplitStrings;
GO

CREATE FUNCTION dbo.SplitStrings (@inputString varchar(1000), @delimeter varchar(1))

RETURNS TABLE
AS
  RETURN
  SELECT
    Item = Y.i.value('(./text())[1]', 'nvarchar(4000)')
  FROM (SELECT
    X = CONVERT(xml, '<i>'
    + REPLACE(@inputString, @delimeter, '</i><i>')
    + '</i>').query('.')) AS A
  CROSS APPLY X.nodes('i') AS Y (i);
GO

-- Проверяет входят ли все слова из строки @searchString в строку @sourceString
IF OBJECT_ID('dbo.IsLineMatched') IS NOT NULL
  DROP FUNCTION dbo.IsLineMatched;
GO

CREATE FUNCTION dbo.IsLineMatched (@searchString varchar(1000), @sourceString varchar(1000))

RETURNS bit
AS
BEGIN

  DECLARE @result bit = 0;

  IF EXISTS ((SELECT
      LOWER(A.Item)
    FROM dbo.SplitStrings(@searchString, ' ') AS A
    GROUP BY A.Item
    EXCEPT
    SELECT
      LOWER(A.Item)
    FROM dbo.SplitStrings(@sourceString, ' ') AS A
    GROUP BY A.Item
    ))
  BEGIN
    SET @result = 1
  END

  RETURN @result
END

GO

-- Удаляем избыточные строки
DELETE AP
  FROM AutoParts AP
  INNER JOIN (SELECT
    T1.code_cat,
    T1.class_cat
  FROM AutoParts AS T1
  INNER JOIN AutoParts AS T2
    ON T1.code_cat = T2.code_cat
    AND (T1.class_cat != T2.class_cat)
  WHERE dbo.IsLineMatched(T1.class_cat, T2.class_cat) = 0
  GROUP BY T1.code_cat,
           T1.class_cat) AS deleteList (code_cat, class_cat)
    ON AP.code_cat = deleteList.code_cat
    AND AP.class_cat = deleteList.class_cat

-- Удаляем полностью дублируемые строки, жертву выбираем случайно.
;
WITH a
AS
(SELECT
  AP.code_cat,
  AP.class_cat,
  ROW_NUMBER() OVER (PARTITION BY AP.code_cat, AP.class_cat ORDER BY NEWID()) AS b
FROM AutoParts AS AP)
DELETE FROM a
WHERE b > 1


-- Проверка 
SELECT
  *
FROM AutoParts AS AP

-- Все чистим
DROP FUNCTION dbo.SplitStrings;
DROP FUNCTION dbo.IsLineMatched;
DROP TABLE dbo.AutoParts;
