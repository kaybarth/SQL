/*
OBTENER INSERT DESDE REGISTRO
*/

-- Parametros de entrada al procedimiento
DECLARE
@Tabla		VARCHAR(100) = 'Venta',
@Codicion	VARCHAR(MAX) = 'ID = 753291'

DECLARE 
	@ValoresConcatenados 	NVARCHAR(MAX) = '',
	@ColumnasConcatenadas 	NVARCHAR(MAX) = '',
	@Columna 				NVARCHAR(MAX),
	@QueryValor 			NVARCHAR(MAX),
	@VALOR 					NVARCHAR(MAX),
	@Params 				NVARCHAR(MAX) = '@Valor NVARCHAR(MAX) OUTPUT',
	@ValorColumna 			NVARCHAR(MAX),
	@Insert					NVARCHAR(MAX),
	@Where					VARCHAR(MAX) = ''

IF @Codicion <> ''
	SET @Where = 'WHERE '+@Codicion
		
-- Declarar el cursor para obtener la lista de columnas
DECLARE ColumnasCursor CURSOR FOR
    SELECT 
		COLUMN_NAME
    FROM 
		INFORMATION_SCHEMA.COLUMNS
    WHERE 
		TABLE_NAME = @Tabla

-- Abrir el cursor
OPEN ColumnasCursor;

-- Inicializar la variable para almacenar el nombre de la columna actual
FETCH NEXT FROM ColumnasCursor INTO @Columna;

IF OBJECT_ID('tempdb.dbo.#SalidaValores') IS NOT NULL  
	DROP TABLE #SalidaValores 

IF OBJECT_ID('tempdb.dbo.#CamposExcluidos') IS NOT NULL  
	DROP TABLE #CamposExcluidos

CREATE TABLE #SalidaValores (
	SALIDA VARCHAR(MAX) NULL
	)

CREATE TABLE #CamposExcluidos (
	Campo VARCHAR(MAX)
	)

-- Identifica los campos que son de tipo identidad, tipo es timestamp o son calculados
INSERT INTO #CamposExcluidos
	SELECT 
		COLUMN_NAME
	FROM 
		INFORMATION_SCHEMA.COLUMNS
	WHERE 
		TABLE_NAME = @Tabla 
		AND (
			COLUMNPROPERTY(OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME), COLUMN_NAME, 'IsIdentity') = 1
			OR DATA_TYPE = 'timestamp'
		)
	UNION ALL
	SELECT 
		c.name AS COLUMN_NAME
	FROM 
		sys.columns c
	JOIN 
		sys.tables t ON c.object_id = t.object_id
	WHERE 
		t.name = @Tabla
		AND c.is_computed = 1;

-- Recorrer las columnas y concatenar los valores
WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT EXISTS(SELECT * FROM #CamposExcluidos WHERE Campo = @Columna)
	BEGIN
		-- Obtenemos los valores de la columna correspondiente
		SET @QueryValor = 'SELECT TOP 1 ' + QUOTENAME(@Columna) + ' FROM '+@Tabla+' '+@Where;

		INSERT INTO #SalidaValores
		EXEC sp_executesql @QueryValor
	
		SELECT TOP 1 @VALOR = SALIDA FROM #SalidaValores
		TRUNCATE TABLE #SalidaValores

		SET @ValoresConcatenados = @ValoresConcatenados + 
			COALESCE('''' + CONVERT(NVARCHAR(MAX), (@VALOR)) + '''', 'NULL');

		SET @ColumnasConcatenadas = @ColumnasConcatenadas + 
			COALESCE(CONVERT(NVARCHAR(MAX), (@Columna)), '');
		
		FETCH NEXT FROM ColumnasCursor INTO @Columna;
		-- Agregar coma si no es la última columna
		IF @@FETCH_STATUS = 0
		BEGIN
			SELECT 
				@ValoresConcatenados 	= @ValoresConcatenados	+ ', ', 
				@ColumnasConcatenadas 	= @ColumnasConcatenadas + ', '
		END
	END
	ELSE
		FETCH NEXT FROM ColumnasCursor INTO @Columna;
	
END

-- Cerrar y liberar el cursor
CLOSE ColumnasCursor;
DEALLOCATE ColumnasCursor;

SET @Insert = 'INSERT INTO '+@Tabla+' ('+@ColumnasConcatenadas+') VALUES ('+@ValoresConcatenados+')'

-- 
select @Insert;
