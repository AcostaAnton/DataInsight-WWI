/*
DataInsight WWI - Exploración inicial de la fuente.
Seleccionar WideWorldImporters en el desplegable de bases de datos de SSMS.
Todas las instrucciones ejecutables de este archivo son SELECT.
Ejecutar las secciones 1 a 5 antes de la sección 6.
Los resultados deben obtenerse de la instancia restaurada del usuario.
*/

-- 1. Contexto y conteos exactos. Comparar con los conteos documentados.
SELECT DB_NAME() AS base_de_datos;

SELECT N'Sales.Orders' AS tabla, COUNT_BIG(*) AS registros FROM Sales.Orders
UNION ALL
SELECT N'Sales.OrderLines', COUNT_BIG(*) FROM Sales.OrderLines
UNION ALL
SELECT N'Sales.Invoices', COUNT_BIG(*) FROM Sales.Invoices
UNION ALL
SELECT N'Sales.InvoiceLines', COUNT_BIG(*) FROM Sales.InvoiceLines
UNION ALL
SELECT N'Sales.Customers', COUNT_BIG(*) FROM Sales.Customers
UNION ALL
SELECT N'Warehouse.StockItems', COUNT_BIG(*) FROM Warehouse.StockItems;

-- 2. Columnas, tipos, nulabilidad, identidad y valores predeterminados.
-- max_length se expresa en bytes (-1 indica MAX).
SELECT
    s.name AS esquema,
    t.name AS tabla,
    c.column_id AS posicion,
    c.name AS columna,
    ty.name AS tipo,
    c.max_length AS longitud_bytes,
    c.precision AS precision_numerica,
    c.scale AS escala,
    c.is_nullable AS permite_null,
    c.is_identity AS es_identidad,
    c.is_computed AS es_calculada,
    dc.definition AS valor_predeterminado
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c ON c.object_id = t.object_id
INNER JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints AS dc ON dc.object_id = c.default_object_id
WHERE (s.name = N'Sales' AND t.name IN
    (N'Orders', N'OrderLines', N'Invoices', N'InvoiceLines', N'Customers'))
    OR (s.name = N'Warehouse' AND t.name = N'StockItems')
ORDER BY s.name, t.name, c.column_id;

-- 3. Claves primarias e índices únicos, incluidas claves compuestas.
-- Solo aparecen columnas de la clave del índice.
SELECT
    s.name AS esquema,
    t.name AS tabla,
    i.name AS indice,
    i.is_primary_key AS es_clave_primaria,
    i.is_unique_constraint AS es_restriccion_unica,
    i.is_disabled AS esta_deshabilitado,
    i.has_filter AS tiene_filtro,
    i.filter_definition AS filtro,
    ic.key_ordinal AS posicion_en_clave,
    c.name AS columna
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.indexes AS i ON i.object_id = t.object_id
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id AND ic.index_id = i.index_id
INNER JOIN sys.columns AS c
    ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.is_unique = 1 AND ic.key_ordinal > 0
    AND ((s.name = N'Sales' AND t.name IN
        (N'Orders', N'OrderLines', N'Invoices', N'InvoiceLines', N'Customers'))
        OR (s.name = N'Warehouse' AND t.name = N'StockItems'))
ORDER BY s.name, t.name, i.name, ic.key_ordinal;

-- 4. Relaciones declaradas que salen de o llegan a las seis tablas.
-- Una fila por par de columnas. Una FK compuesta produce varias filas.
-- Pueden aparecer tablas externas a las seis seleccionadas.
SELECT
    fk.name AS clave_foranea,
    ps.name AS esquema_origen,
    pt.name AS tabla_origen,
    pc.name AS columna_origen,
    rs.name AS esquema_referenciado,
    rt.name AS tabla_referenciada,
    rc.name AS columna_referenciada,
    fkc.constraint_column_id AS posicion_en_relacion,
    fk.is_disabled AS esta_deshabilitada,
    fk.is_not_trusted AS sin_validacion_completa,
    fk.delete_referential_action_desc AS accion_delete,
    fk.update_referential_action_desc AS accion_update
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.tables AS pt ON pt.object_id = fk.parent_object_id
INNER JOIN sys.schemas AS ps ON ps.schema_id = pt.schema_id
INNER JOIN sys.columns AS pc
    ON pc.object_id = pt.object_id AND pc.column_id = fkc.parent_column_id
INNER JOIN sys.tables AS rt ON rt.object_id = fk.referenced_object_id
INNER JOIN sys.schemas AS rs ON rs.schema_id = rt.schema_id
INNER JOIN sys.columns AS rc
    ON rc.object_id = rt.object_id AND rc.column_id = fkc.referenced_column_id
WHERE (ps.name = N'Sales' AND pt.name IN
        (N'Orders', N'OrderLines', N'Invoices', N'InvoiceLines', N'Customers'))
    OR (ps.name = N'Warehouse' AND pt.name = N'StockItems')
    OR (rs.name = N'Sales' AND rt.name IN
        (N'Orders', N'OrderLines', N'Invoices', N'InvoiceLines', N'Customers'))
    OR (rs.name = N'Warehouse' AND rt.name = N'StockItems')
ORDER BY ps.name, pt.name, fk.name, fkc.constraint_column_id;

-- 5. Reglas CHECK declaradas. Complementar con reglas de negocio documentadas.
SELECT
    s.name AS esquema,
    t.name AS tabla,
    cc.name AS restriccion,
    cc.definition AS regla,
    cc.is_disabled AS esta_deshabilitada,
    cc.is_not_trusted AS sin_validacion_completa
FROM sys.check_constraints AS cc
INNER JOIN sys.tables AS t ON t.object_id = cc.parent_object_id
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE (s.name = N'Sales' AND t.name IN
    (N'Orders', N'OrderLines', N'Invoices', N'InvoiceLines', N'Customers'))
    OR (s.name = N'Warehouse' AND t.name = N'StockItems')
ORDER BY s.name, t.name, cc.name;

-- 6. Ejecutar solo después de confirmar en 2, 3 y 4 que existen
-- Sales.Orders.OrderID (único) y Sales.Invoices.OrderID, y verificar su relación.
-- Cuenta facturas por pedido sin multiplicar registros por líneas.
-- Cero facturas vinculadas no identifica por sí solo el estado comercial del pedido.
SELECT
    CASE
        WHEN resumen.facturas_vinculadas = 0 THEN N'0 facturas vinculadas'
        WHEN resumen.facturas_vinculadas = 1 THEN N'1 factura vinculada'
        ELSE N'Mas de 1 factura vinculada'
    END AS grupo,
    COUNT_BIG(*) AS pedidos
FROM (
    SELECT o.OrderID, COUNT_BIG(i.OrderID) AS facturas_vinculadas
    FROM Sales.Orders AS o
    LEFT JOIN Sales.Invoices AS i ON i.OrderID = o.OrderID
    GROUP BY o.OrderID
) AS resumen
GROUP BY
    CASE
        WHEN resumen.facturas_vinculadas = 0 THEN N'0 facturas vinculadas'
        WHEN resumen.facturas_vinculadas = 1 THEN N'1 factura vinculada'
        ELSE N'Mas de 1 factura vinculada'
    END;

-- Confirmar OrderID en Invoices antes de ejecutar esta consulta también.
SELECT
    COUNT_BIG(*) AS facturas_totales,
    COUNT_BIG(OrderID) AS facturas_con_orderid,
    COUNT_BIG(*) - COUNT_BIG(OrderID) AS facturas_sin_orderid
FROM Sales.Invoices;
