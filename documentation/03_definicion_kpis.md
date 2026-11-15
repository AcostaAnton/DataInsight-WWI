# Definición de KPI de ventas

## Estado y alcance

Resultados reales de WideWorldImporters comunicados para esta actualización. Rango observado: **2013-01-01 a 2016-05-31** (41 meses, de enero de 2013 a mayo de 2016). No se ejecutaron consultas contra la base durante esta edición. El script `database/source/02_validacion_kpis_calidad.sql` separa las consultas optimizadas de las comprobaciones originales de referencia.

Las consultas optimizadas se usan por las limitaciones de memoria de SQL Server Express: los JOIN problemáticos se resolvieron con `LOOP JOIN` y `OPTION (MAXDOP 1)`. Estas opciones de ejecución no cambian la definición de los KPI. Las consultas de KPI abarcan toda la fuente visible; el rango indicado es el observado, no un filtro añadido.

## 1. Ventas totales

| Medida | Resultado |
| --- | ---: |
| Líneas de factura | 228265 |
| Ventas sin impuestos | 172261341.20 |
| Impuestos registrados | 25782098.25 |
| Ventas con impuestos | 198043439.45 |

Fuente: `Sales.InvoiceLines`, vinculada a `Sales.Invoices` por `InvoiceID`, con `IsCreditNote = 0`. Granularidad: línea de factura; fecha: `InvoiceDate`. Base sin impuestos: `SUM(Quantity * UnitPrice)`; impuestos: `SUM(TaxAmount)`; total con impuestos: `SUM(ExtendedPrice)`. El total comunicado coincide con base más impuestos. No se detectaron diferencias superiores a 0.01 en las comprobaciones monetarias realizadas de `ExtendedPrice` frente a `Quantity * UnitPrice + TaxAmount`.

La validación detallada del impuesto a partir de `TaxRate`, base gravable, exenciones y redondeo permanece **pendiente**. El importe agregado de impuestos no acredita esa validación. La moneda y las reglas de negocio definitivas deben confirmarse antes del ETL.

## 2. Facturas emitidas

**70510 facturas**, todas con `IsCreditNote = 0`. El conteo se realiza directamente en `Sales.Invoices` para evitar multiplicarlo por las líneas. Fecha de referencia: `InvoiceDate`; granularidad: una cabecera por `InvoiceID`.

No se observaron notas de crédito en esta población. Su tratamiento en futuras cargas y el cálculo de ventas netas siguen requiriendo una decisión de negocio; no se invierten signos automáticamente.

## 3. Productos más vendidos

Ranking **top 10 por cantidad**, agrupado por `StockItemID` y `PackageTypeID`, con `SUM(Quantity)` y orden descendente. Fuente: líneas y cabeceras de factura, con `IsCreditNote = 0`; fecha: `InvoiceDate`. `Warehouse.StockItems` aporta el nombre del producto. Los empates se ordenan por `StockItemID` y `PackageTypeID`.

Líder comunicado: **StockItemID 191, con 207324 unidades**. No se proporcionaron el `PackageTypeID` del líder ni las otras nueve filas; quedan pendientes de incorporar desde la salida real. No se inventan nombres, presentaciones ni posiciones. No combinar presentaciones distintas sin una conversión validada.

## 4. Ventas por cliente

Ranking **top 10 clientes por ventas sin impuestos**, calculado como `SUM(Quantity * UnitPrice)` por `Invoices.CustomerID`, con `IsCreditNote = 0`. Fuente: `Sales.Invoices`, `Sales.InvoiceLines` y `Sales.Customers` para la etiqueta. Fecha: `InvoiceDate`; granularidad: cliente comercial. Los empates se ordenan por `CustomerID`.

Líder comunicado: **CustomerID 149, con 381585.35**. Las otras nueve filas y los nombres no se proporcionaron y quedan pendientes de incorporar desde la salida real. El ranking utiliza `CustomerID`; elegir `BillToCustomerID` para otro análisis requiere una decisión de negocio.

## 5. Ventas mensuales

Agrupación por año y mes de `InvoiceDate`, con `SUM(Quantity * UnitPrice)` y `IsCreditNote = 0`. Se observaron **41 meses**, desde **enero de 2013 hasta mayo de 2016**, con un total de ventas sin impuestos de **172261341.20**, coincidente con el KPI 1.

No se dispone aquí de los importes de cada mes. No se infieren valores mensuales ni se rellenan meses ausentes con cero. Esta coincidencia agregada no completa la conciliación de la sección 7 del SQL.

## 6. Pedidos sin factura

| Medida | Resultado |
| --- | ---: |
| Total de pedidos | 73595 |
| Pedidos con factura | 70510 |
| Pedidos sin factura | 3085 |
| Porcentaje sin factura | 4.19% |

Fuente: `Sales.Orders` y existencia de cualquier cabecera vinculada en `Sales.Invoices` por `OrderID`. Granularidad: pedido; fecha de referencia de la cohorte: `OrderDate`. Fórmula: `100.0 * pedidos_sin_factura / total_pedidos`, redondeada a dos decimales. El denominador y numerador usan la misma población de pedidos, sin filtrar la existencia de factura por fecha ni por `IsCreditNote`.

Los pedidos sin factura no se clasifican automáticamente como cancelados o pendientes. Una medición histórica a fecha de corte requiere definir qué documentos posteriores se consideran.

## Calidad comprobada y pendientes

En las comprobaciones realizadas no se detectaron claves duplicadas, relaciones huérfanas, diferencias monetarias superiores a 0.01 ni facturas con fecha anterior al pedido. El alcance de estos hallazgos se detalla en `04_reglas_calidad_datos.md`; no certifican controles que no tengan resultado comunicado.

Permanecen pendientes la **conciliación completa de la sección 7**, la **validación detallada de impuestos**, la incorporación de las filas completas de los rankings y las decisiones sobre moneda, créditos, unidades, tolerancia definitiva y excepciones. `SUM` omite nulos: no sustituirlos por cero ni dar por validados los perfiles sin evidencia. Esta etapa no incluye ETL ni modificación de datos.
