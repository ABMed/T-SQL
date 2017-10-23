IF OBJECT_ID('dbo.usp_ReIndex') IS NOT NULL
  SET NOEXEC ON
GO
CREATE PROCEDURE dbo.usp_ReIndex(@dbName nvarchar(128))
AS RETURN
BEGIN
    SET NOCOUNT ON;
IF (@dbName IS NULL OR @dbName = '') THROW 50000,'Database name not specified or the parameter @dbName is not initiated',16

DECLARE @rebuildIndexTemplate nvarchar(300);
DECLARE @reorganizeIndexTemplate nvarchar(300);

DECLARE @indexOperationCmd nvarchar(300) = '';

DECLARE @indexName nvarchar(128);
DECLARE @tableName nvarchar(128);
DECLARE @defragmentationAction nvarchar(10);
DECLARE @startTime datetime;
DECLARE @stopTime datetime;

DECLARE @indexList AS TABLE (
  indexName nvarchar(128),
  tableName nvarchar(128),
  defragmentationAction varchar(10)
);

DECLARE indexListCursor CURSOR FAST_FORWARD READ_ONLY LOCAL FOR
SELECT
  indexName,
  tableName,
  defragmentationAction
FROM @indexList

SET @rebuildIndexTemplate = 'ALTER INDEX $INDEX_NAME_PLACEHOLDER$ ON $TABLE_NAME_PLACEHOLDER$ REBUILD;';
SET @reorganizeIndexTemplate = 'ALTER INDEX $INDEX_NAME_PLACEHOLDER$ ON $TABLE_NAME_PLACEHOLDER$ REORGANIZE;';

INSERT INTO @indexList (indexName, tableName, defragmentationAction)
  SELECT
    I.Name AS indexName,
    @dbName + '.' + SCHEMA_NAME(O.schema_id) + '.' + OBJECT_NAME(DDIPS.object_id) AS tableName,
    CASE
      WHEN DDIPS.avg_fragmentation_in_percent <= 30.0 THEN 'REORGANIZE'
      WHEN DDIPS.avg_fragmentation_in_percent > 30.0 THEN 'REBUILD'
    END AS defragmentationAction
  FROM sys.dm_db_index_physical_stats(DB_ID(@dbName), NULL, NULL, NULL, NULL) AS DDIPS
  JOIN sys.indexes AS I
    ON DDIPS.object_id = I.object_id
  JOIN sys.objects AS O
    ON DDIPS.object_id = O.object_id
  WHERE I.type IN (1, 2)
  AND I.is_disabled = 0
  AND DDIPS.avg_fragmentation_in_percent > 5.0
  AND DDIPS.page_count > 8
  ORDER BY I.type;

OPEN indexListCursor

FETCH NEXT FROM indexListCursor INTO @indexName, @tableName, @defragmentationAction

WHILE @@fetch_status = 0
BEGIN

  IF (@defragmentationAction = 'REBUILD')
  BEGIN
    SET @indexOperationCmd = REPLACE(@rebuildIndexTemplate, '$INDEX_NAME_PLACEHOLDER$', @indexName);
    SET @indexOperationCmd = REPLACE(@indexOperationCmd, '$TABLE_NAME_PLACEHOLDER$', @tableName);
  --PRINT @indexOperationCmd
  END

  IF (@defragmentationAction = 'REORGANIZE')
  BEGIN
    SET @indexOperationCmd = REPLACE(@reorganizeIndexTemplate, '$INDEX_NAME_PLACEHOLDER$', @indexName);
    SET @indexOperationCmd = REPLACE(@indexOperationCmd, '$TABLE_NAME_PLACEHOLDER$', @tableName);
  --PRINT @indexOperationCmd
  END

  IF (@indexOperationCmd <> ''
    OR @indexOperationCmd IS NOT NULL)
  BEGIN
    SET @startTime = current_timestamp
    PRINT CONCAT('Action ', LOWER(@defragmentationAction), ' on ', @indexName, ' started.')
    PRINT CONCAT('Satred at ', FORMAT(@startTime, 'dd.MM.yyyy HH:mm:ss'))
    EXEC (@indexOperationCmd)
    SET @stopTime = current_timestamp
    PRINT CONCAT('Ended at ', FORMAT(@stopTime, 'dd.MM.yyyy HH:mm:ss'))
    PRINT CONCAT('Duration: ', DATEDIFF(SECOND, @startTime, @stopTime), ' seconds.')
  END


  SET @indexOperationCmd = '';
  FETCH NEXT FROM indexListCursor INTO @indexName, @tableName, @defragmentationAction
END

CLOSE indexListCursor;
DEALLOCATE indexListCursor;
  
SET NOEXEC OFF;
    RETURN 0;
END;
GO
