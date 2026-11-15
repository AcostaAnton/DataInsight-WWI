"""Prueba de lectura de WideWorldImporters con autenticación de Windows."""

import os
import sys
from contextlib import closing


DRIVERS = ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server")
ODBC_URL = "https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server"


def setting(name, default):
    value = os.environ.get(name, default).strip()
    if not value:
        raise ValueError(f"La variable {name} no puede estar vacía.")
    return value


def odbc_value(value):
    # Escapar valores impide que ';' introduzca opciones adicionales.
    return "{" + value.replace("}", "}}") + "}"


def main():
    try:
        import pyodbc
    except ImportError:
        print(
            "Falta pyodbc. Desde la raíz del proyecto ejecuta: "
            r".\.venv\Scripts\python.exe -m pip install -r .\etl\requirements.txt",
            file=sys.stderr,
        )
        return 1

    try:
        available = pyodbc.drivers()
        supported = [driver for driver in DRIVERS if driver in available]
        if not supported:
            raise ValueError(
                "No hay ODBC Driver 17 ni 18 for SQL Server visible para este Python. "
                "Instala Microsoft ODBC Driver 18 for SQL Server para Windows con "
                "arquitectura compatible con Python y vuelve a ejecutar el script. "
                f"Descarga oficial: {ODBC_URL}"
            )
        requested = os.environ.get("SQLSERVER_ODBC_DRIVER", "").strip()
        if requested and requested not in supported:
            raise ValueError(
                f"SQLSERVER_ODBC_DRIVER debe ser uno disponible: {', '.join(supported)}. "
                "Déjala vacía para selección automática."
            )
        driver = requested or supported[0]
        server = setting("SQLSERVER_HOST", r"ANTON\SQLEXPRESS")
        database = setting("SQLSERVER_DATABASE", "WideWorldImporters")
        encrypt = setting("SQLSERVER_ENCRYPT", "yes").lower()
        trust = setting("SQLSERVER_TRUST_SERVER_CERTIFICATE", "no").lower()
        if encrypt not in ("yes", "no") or trust not in ("yes", "no"):
            raise ValueError("ENCRYPT y TRUST_SERVER_CERTIFICATE deben valer yes o no.")
        connection_string = (
            f"DRIVER={odbc_value(driver)};SERVER={odbc_value(server)};"
            f"DATABASE={odbc_value(database)};Trusted_Connection=yes;"
            f"Encrypt={encrypt};TrustServerCertificate={trust};"
        )
        print(f"Controlador: {driver}")
        print(f"Destino: {server} / {database} (autenticación integrada de Windows)")
        with closing(pyodbc.connect(connection_string, timeout=10, autocommit=True)) as connection:
            connection.timeout = 30
            with closing(connection.cursor()) as cursor:
                cursor.execute("SELECT @@VERSION;")
                version = cursor.fetchone()[0]
                cursor.execute("SELECT COUNT_BIG(*) FROM Sales.Invoices;")
                invoices = cursor.fetchone()[0]
        print("Conexión verificada.")
        print(f"Versión de SQL Server:\n{version}")
        print(f"COUNT_BIG(*) de Sales.Invoices: {invoices}")
        return 0
    except ValueError as error:
        print(f"Configuración: {error}", file=sys.stderr)
        return 1
    except pyodbc.Error as error:
        # Mostrar SQLSTATE sin volcar la cadena de conexión ni detalles sensibles.
        state = str(error.args[0]) if error.args else "desconocido"
        print(
            f"Falló la prueba SQL Server (SQLSTATE {state}). "
            "Revisa la instancia, el servicio SQL Server, el acceso de tu usuario "
            "de Windows a WideWorldImporters y la configuración TLS. "
            "Consulta documentation/05_conexion_sqlserver.md.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
