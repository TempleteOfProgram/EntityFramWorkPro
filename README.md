
Some "dotnet" CLI:
===============================================================================
> Reference: https://www.nuget.org/packages

1. Create new MVC project:
    - dotnet new mvc
2. Run dotnet project:
    - dotnet run
3. Dotnet install EntityFram_Work:
    - dotnet add package Microsoft.EntityFrameworkCore.SqlServer --version 3.1.2
4. Dotnet install NewtonSoft Json:
    - dotnet add package Newtonsoft.Json --version 12.0.3
5. Dotnet Hagfire for multitaksking:
    - dotnet add package HangFire.Core --version 1.7.9
6. Dotnet Identity Server:
    - dotnet add package IdentityServer4 --version 4.0.0-preview.2
7. Dotnet IIS server:
    - dotnet add package Microsoft.AspNetCore.Server.IIS --version 2.2.6
8. Dotnet Async Dispose:
    - dotnet add package Nito.Disposables --version 2.1.0-pre02







Some useful MSSQL CMD:
==============================================
1. start MSSQL:
    - sqlcmd -S localhost -U SA -P 'K......12@'

2. Create SnowDB:
    - CREATE DATABASE SnowDB

3. Show ALL DB:
    - SELECT Name from sys.Databases

4. EXECUTE:
    - GO

5. USE SnowDB:
    - USE SnowDB

6. Create Inventory Table:
    - CREATE TABLE Inventory (id INT, name NVARCHAR(50), quantity INT)

7. Insert Data in the Inventory Table:
    - INSERT INTO Inventory VALUES (1, 'banana', 150); INSERT INTO Inventory VALUES (2, 'orange', 154);

8. Execute:
    - GO

9. Query Data from Inventory Table:
    - SELECT * FROM Inventory WHERE quantity > 152;

10. Execute:
    - GO

11. Stop SqlCmd Session:
    - QUIT
