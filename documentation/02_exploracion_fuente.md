# Exploración inicial de WideWorldImporters

## Estado y procedencia

WideWorldImporters fue restaurada en SQL Server. Los siguientes conteos fueron obtenidos mediante consultas reales ejecutadas por el autor del proyecto y comunicados para esta documentación. No se realizó una conexión a SQL Server desde esta preparación del repositorio. La fecha de ejecución de los conteos no fue proporcionada.

La revisión del repositorio confirmó las carpetas de documentación, bases de datos, ETL, backend, frontend, Machine Learning, IA generativa, notificaciones, pruebas y despliegue, junto con README.md, .gitignore, .env.example y los archivos .gitkeep.

## Conteos reales proporcionados

| Tabla | Registros |
| --- | ---: |
| Sales.Orders | 73 595 |
| Sales.OrderLines | 231 412 |
| Sales.Invoices | 70 510 |
| Sales.InvoiceLines | 228 265 |
| Sales.Customers | 663 |
| Warehouse.StockItems | 227 |

Estos valores describen el estado consultado de la fuente. Una nueva ejecución debe registrar sus propios resultados si los datos han cambiado.

## Función de las tablas

Las siguientes descripciones expresan el papel funcional de las tablas. Sus columnas y reglas concretas deben confirmarse en la base restaurada.

| Tabla | Explicación sencilla |
| --- | --- |
| Sales.Orders | Cabeceras de pedidos realizados por clientes. Representan la solicitud comercial. |
| Sales.OrderLines | Detalles de los artículos solicitados en cada pedido, con las cantidades y condiciones que se confirmen en sus columnas. |
| Sales.Invoices | Cabeceras de facturas emitidas. Representan la facturación de la operación comercial. |
| Sales.InvoiceLines | Detalles de los artículos facturados, con las cantidades e importes que se confirmen en sus columnas. |
| Sales.Customers | Datos maestros de clientes que participan en las operaciones comerciales. |
| Warehouse.StockItems | Catálogo de artículos utilizados en las operaciones de venta y almacén. |

## Pedidos y facturas

Un pedido representa una solicitud del cliente. Una factura registra su facturación. Debemos analizar por separado las cabeceras y las líneas de cada proceso.

El autor del proyecto ejecutó las secciones 1 a 6 del script `database/source/01_exploracion_inicial.sql` y confirmó los siguientes metadatos y resultados en su instancia de WideWorldImporters.

- `Sales.Orders.OrderID` es clave primaria.
- `Sales.Invoices.OrderID` tiene una clave foránea hacia `Sales.Orders.OrderID` y admite `NULL`.

| Vinculación de pedidos | Pedidos | Porcentaje aproximado del total de pedidos |
| --- | ---: | ---: |
| Con 1 factura vinculada | 70 510 | 95.81% |
| Con 0 facturas vinculadas | 3 085 | 4.19% |
| Con más de 1 factura vinculada | 0 | 0% |
| Total | 73 595 | 100% |

Los porcentajes utilizan como denominador los 73 595 pedidos.

| Comprobación de facturas | Facturas |
| --- | ---: |
| Facturas totales | 70 510 |
| Facturas con OrderID | 70 510 |
| Facturas sin OrderID | 0 |

En los datos consultados, cada pedido tiene cero o una factura vinculada y todas las facturas tienen OrderID. La columna nullable permite que una factura tenga OrderID nulo, aunque ese caso no apareció en los resultados. La clave foránea y la clave primaria del pedido no garantizan por sí solas una única factura por pedido. Para confirmar ese límite en el esquema todavía debemos comprobar si existe una restricción o índice único sobre `Sales.Invoices.OrderID`.

Los 3 085 pedidos sin factura vinculada no deben clasificarse automáticamente como cancelados o pendientes. Su estado comercial requiere validar las columnas y reglas de negocio correspondientes. Estos resultados tampoco establecen por sí solos si un pedido está parcial o totalmente facturado.

Las líneas de pedidos y las de facturas tienen granularidades propias. Unirlas directamente por pedido o artículo podría multiplicar filas. La correspondencia exacta entre ambas requiere investigación antes de calcular indicadores conjuntos.

### Criterio para calcular ingresos

Los ingresos se calcularán a partir de las líneas de factura de `Sales.InvoiceLines`, previa validación de los impuestos, el tratamiento de notas de crédito y la definición del KPI. Debemos confirmar las columnas e importes que se utilizarán, si el indicador incluye o excluye impuestos, cómo se aplican devoluciones y notas de crédito y qué fecha y moneda corresponden. La fórmula y los importes de ingresos permanecen pendientes de validación.

## Comprobaciones pendientes

### Columnas y claves

- Confirmar los nombres, tipos, longitudes, precisión, escala, nulabilidad y valores predeterminados mediante la sección 2.
- Completar la revisión de las claves primarias y únicas de las demás tablas mediante la sección 3, incluyendo si son compuestas. Sales.Orders.OrderID ya está confirmado como clave primaria.
- Revisar como candidatos OrderLineID, InvoiceID, InvoiceLineID, CustomerID y StockItemID. Su existencia y función aún no están verificadas en esta documentación. OrderID ya está confirmado en Orders e Invoices.
- Identificar fechas de pedido, factura, entrega y última modificación, así como sus rangos y significado.
- Identificar cantidades, precios, impuestos, importes, beneficios y estados disponibles. Confirmar unidades, moneda y fórmulas antes de agregarlos.

### Relaciones

Completar mediante la sección 4 la verificación de las siguientes relaciones y las columnas exactas que las implementan. La relación entre Orders e Invoices ya tiene confirmaciones específicas, documentadas arriba.

| Relación candidata | Qué verificar |
| --- | --- |
| Orders con OrderLines | Clave de enlace, integridad y cantidad de líneas por pedido. |
| Invoices con InvoiceLines | Clave de enlace, integridad y cantidad de líneas por factura. |
| Orders con Invoices | Enlace por OrderID y nulabilidad de Invoices.OrderID confirmados. Se observaron cero o una factura por pedido. Falta verificar si existe unicidad declarada en Invoices.OrderID y el estado habilitado y validado de la clave foránea. |
| Customers con Orders e Invoices | Roles del cliente, incluido el posible cliente de facturación, y claves utilizadas. |
| StockItems con OrderLines e InvoiceLines | Clave del artículo, integridad y tratamiento de artículos históricos. |
| OrderLines con InvoiceLines | Existencia de un enlace directo o reglas que permitan relacionar los detalles. |

La sección 4 muestra relaciones entrantes y salientes, incluso con otras tablas. Una clave foránea declarada debe evaluarse junto con su estado habilitado y validado. Las claves únicas y la nulabilidad ayudan a interpretar la cardinalidad permitida. Los datos permiten medir la cardinalidad observada.

Los metadatos visibles dependen de los permisos de la cuenta utilizada. Una consulta de metadatos sin filas requiere revisar el contexto de base de datos y los permisos antes de concluir que no existen restricciones.

### Reglas de negocio y calidad

- Establecer cuándo un pedido se considera pendiente, completado, cancelado o parcialmente facturado y si esos estados están representados en la fuente.
- Investigar el estado comercial de los 3 085 pedidos sin factura vinculada. En la consulta realizada no se observaron pedidos con varias facturas ni facturas sin OrderID. Revisar las reglas que permiten o restringen esos casos.
- Investigar pedidos relacionados con otros pedidos, como posibles pedidos pendientes de suministro, si el esquema los contempla.
- Definir el tratamiento de devoluciones, notas de crédito, cantidades negativas, impuestos y redondeos, si aparecen en los datos.
- Definir la fórmula, fecha y moneda del KPI de ingresos a partir de líneas de factura, previa validación de impuestos y notas de crédito. Definir por separado los indicadores de pedidos.
- Revisar valores nulos, duplicados según la clave de negocio, referencias huérfanas y coherencia entre cabeceras y líneas mediante consultas posteriores.
- Revisar las restricciones CHECK de la sección 5 y contrastarlas con las reglas funcionales. Las restricciones declaradas cubren solo las reglas implementadas en la base.

## Ejecución en SSMS

Abrir `database/source/01_exploracion_inicial.sql` y seleccionar la base restaurada WideWorldImporters en el desplegable de SSMS.

1. Ejecutar la sección 1 para comprobar el contexto y volver a contar las seis tablas.
2. Ejecutar la sección 2 para obtener las columnas y sus características.
3. Ejecutar la sección 3 para identificar claves primarias y únicas.
4. Ejecutar la sección 4 para obtener las relaciones declaradas y sus columnas.
5. Ejecutar la sección 5 para revisar las restricciones CHECK.
6. Confirmar Orders.OrderID como clave única e Invoices.OrderID como columna de enlace y revisar su relación antes de ejecutar las dos consultas de la sección 6. La primera agrupa pedidos por cantidad de facturas vinculadas y la segunda cuenta facturas con y sin OrderID.

Ejecutar primero las secciones 1 a 5 seleccionándolas en el editor. Luego ejecutar la sección 6 por separado cuando se cumplan sus condiciones. Todas las instrucciones ejecutables del archivo son SELECT.

Las secciones 1 a 6 ya fueron ejecutadas por el autor del proyecto. Los resultados de la sección 6 y las confirmaciones de OrderID se incorporaron a esta documentación. Para completar las verificaciones restantes, conservar o compartir los demás resultados de columnas, claves, relaciones y restricciones de las secciones 2 a 5.
