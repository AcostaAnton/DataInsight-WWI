# Prueba de conexión Python a SQL Server

Esta primera etapa implementa únicamente conexión y dos consultas de lectura: `SELECT @@VERSION` y `SELECT COUNT_BIG(*) FROM Sales.Invoices`. No incluye transformaciones, staging, Supabase ni cargas.

## Requisitos y comprobación del entorno

- Windows, Python 3.10 o superior con pip y acceso a la instancia `ANTON\SQLEXPRESS` con la identidad de Windows que ejecuta PowerShell.
- SQL Server iniciado, base `WideWorldImporters` disponible y permiso SELECT sobre `Sales.Invoices`.
- Microsoft ODBC Driver 17 o 18 for SQL Server, compatible con la arquitectura de Python.

Durante la preparación se detectaron ambos controladores (17 y 18) en 32 y 64 bits mediante `Get-OdbcDriver`. Se encontró Python 3.13 en `%LOCALAPPDATA%\Programs\Python\Python313\python.exe`, aunque `python` y `py` no estaban en PATH. Se verificó la sintaxis del script; pyodbc no estaba instalado en ese intérprete. No se ejecutó la conexión real ni se certifica su resultado. Si falta Python, instalar Python para Windows desde https://www.python.org/downloads/windows/ con pip y acceso desde PATH, y abrir otra terminal.

Para comprobar ODBC en PowerShell:

```powershell
Get-OdbcDriver | Where-Object { $_.Name -match 'ODBC Driver (17|18) for SQL Server' } | Select-Object Name, Platform
```

El script comprueba además los controladores visibles para el Python en ejecución. Prefiere 18 y, si no está, usa 17. Si faltan ambos, termina con código 1 y muestra el enlace oficial de instalación: https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server . Instalar el controlador de arquitectura compatible y volver a ejecutar. `pip install pyodbc` no instala el controlador de Microsoft.

## Instalación y ejecución desde la raíz

Estos comandos no requieren activar el entorno virtual:

```powershell
$pythonExe = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python313\python.exe'
& $pythonExe --version
& $pythonExe -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r .\etl\requirements.txt

$env:SQLSERVER_HOST = 'ANTON\SQLEXPRESS'
$env:SQLSERVER_DATABASE = 'WideWorldImporters'
$env:SQLSERVER_ODBC_DRIVER = ''
$env:SQLSERVER_ENCRYPT = 'yes'
$env:SQLSERVER_TRUST_SERVER_CERTIFICATE = 'yes'

.\.venv\Scripts\python.exe .\etl\probar_conexion_sqlserver.py
$LASTEXITCODE
```

Los comandos usan la instalación encontrada en este equipo. En otro equipo con Python en PATH se puede crear el entorno con `python -m venv .venv` o `py -3 -m venv .venv`.

Las variables `$env:` duran lo que dure la sesión y son la configuración que consume el script. `.env.example` es una referencia: el script **no carga archivos `.env` automáticamente**. No se necesita `python-dotenv`. No se utiliza usuario SQL, contraseña ni puerto fijo para la instancia nombrada. La conexión usa siempre `Trusted_Connection=yes` con el usuario de Windows actual.

| Variable | Comportamiento |
| --- | --- |
| SQLSERVER_HOST | Instancia; predeterminado `ANTON\SQLEXPRESS`. |
| SQLSERVER_DATABASE | Predeterminado `WideWorldImporters`. |
| SQLSERVER_ODBC_DRIVER | Vacía o ausente: selección automática 18, luego 17. Puede fijarse al nombre exacto de uno de estos controladores instalado. |
| SQLSERVER_ENCRYPT | `yes` o `no`; predeterminado `yes`. |
| SQLSERVER_TRUST_SERVER_CERTIFICATE | `yes` o `no`; predeterminado `no`. |

Los comandos anteriores usan `TrustServerCertificate=yes` para esta prueba local con certificado autofirmado: mantienen el cifrado y omiten la validación del certificado del servidor. Para un servidor con certificado válido, usar `no`. Referencia de Microsoft: https://learn.microsoft.com/sql/connect/odbc/using-azure-active-directory#new-andor-modified-dsn-and-connection-string-keywords .

## Resultado y diagnóstico

Una ejecución correcta muestra el controlador seleccionado, el destino, la confirmación de conexión, la versión real del servidor y el conteo real de facturas; termina con código 0. La referencia previamente validada es 70510 facturas, pero no se fuerza ese valor ni se simula la salida. Cualquier fallo de configuración o de ODBC termina con código 1. Los recursos se cierran incluso si una consulta falla. La conexión tiene límite de 10 segundos y las consultas de 30 segundos.

- Si falta `pyodbc`, ejecutar el comando de pip indicado arriba.
- Si falta ODBC, instalar el controlador desde el enlace oficial y revisar la arquitectura de Python.
- Ante error de conexión, comprobar servicio e instancia en SSMS con autenticación de Windows. Revisar resolución de la instancia nombrada, SQL Server Browser o configuración de red según corresponda; no se presupone el puerto 1433.
- Ante error de acceso, comprobar permisos del usuario de Windows sobre la base y `Sales.Invoices`.
- Ante error TLS, revisar certificado y las dos variables de cifrado. La excepción muestra SQLSTATE sin volcar la cadena de conexión.

La única dependencia Python es `pyodbc`, declarada en `etl/requirements.txt`. `.venv` y `.env` ya están excluidos por `.gitignore`.
