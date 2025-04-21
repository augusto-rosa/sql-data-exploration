/*

Author: Augusto Rosa

Source: Our World in Data Covid 19

Description: Perform a data exploration analysis using MS SQL Server 

Language Used: SQL, T-SQL

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/
--
-- Ordering both tables for further analysis
--
SELECT * 
FROM staging_data.dbo.tb_covid_deaths
ORDER BY 3,4
--
SELECT * 
FROM staging_data.dbo.tb_covid_vaccinations
ORDER BY 3,4
--
SELECT 
 location
,date
,total_cases
,new_cases
,total_deaths
,population
FROM staging_data.dbo.tb_covid_deaths
ORDER BY 1,2
--
-- Selecting only countries (not null continent)
--
SELECT *
FROM staging_data.dbo.tb_covid_deaths
WHERE 1=1
AND continent IS NOT NULL
ORDER BY 3,4
--
-- Select initial data to begin the analysis
--
SELECT 
 Location
,date
,total_cases
,new_cases
,total_deaths
,population
FROM staging_data.dbo.tb_covid_deaths
WHERE 1=1
AND continent IS NOT NULL
ORDER BY 1,2
--
-- Total Cases vs Total Deaths
-- Shows the probability of dying if you contract COVID-19 in your country
--
SELECT
 Location
,date
,total_cases
,total_deaths
,(CAST(total_deaths AS DECIMAL(10,2))/total_cases) * 100 AS deathPercentage -- Converted to decimal to avoid integer truncation (int/int returns 0)
From staging_data.dbo.tb_covid_deaths
WHERE 1=1
AND location = 'Canada'
AND continent IS NOT NULL 
ORDER BY 1,2
--
-- Total Cases vs Population
-- Shows the percentage of the population infected with COVID-19
--
SELECT 
 Location
,date
,Population
,total_cases
,(CAST(total_cases AS DECIMAL(10,2))/population) * 100 AS PercentPopulationInfected -- -- Converted to decimal to avoid integer truncation
FROM staging_data.dbo.tb_covid_deaths
--WHERE 1=1
--AND location = 'Canada'
ORDER BY 1,2
--
-- Countries with Highest Infection rate compared to Population
--
SELECT 
 Location
,Population
,MAX(total_cases) AS HighestInfectionCount
,Max((total_cases/population)) * 100 AS PercentPopulationInfected
FROM staging_data.dbo.tb_covid_deaths
--WHERE 1=1
--AND location = 'Canada'
GROUP BY Location, Population
ORDER BY PercentPopulationInfected DESC
--
-- Countries with Highest Death Count per Population
--
SELECT 
 Location
,MAX(CAST(Total_deaths AS INT)) AS TotalDeathCount
FROM staging_data.dbo.tb_covid_deaths
WHERE 1=1
--AND location = 'Canada'
AND continent IS NOT NULL
AND location NOT IN ('World', 'Europe', 'North America', 'European Union', 'South America', 'Africa', 'Oceania', 'Asia') -- Apenas paises e não continentes...
GROUP BY Location
ORDER BY TotalDeathCount DESC
--
-- BREAKING INFORMATION DOWN BY CONTINENT
--
-- Showing contintents with the highest death count per population
SELECT
 continent
,MAX(CAST(Total_deaths AS INT)) AS TotalDeathCount
FROM staging_data.dbo.tb_covid_deaths
WHERE 1=1
--AND location = 'Canada'
AND continent IS NOT NULL
AND continent <> ''
GROUP BY continent
ORDER BY TotalDeathCount DESC
--
-- GLOBAL NUMBERS
--
SELECT 
 SUM(CAST(new_cases AS INT)) AS TotalCases
,SUM(CAST(new_deaths AS INT)) AS TotalDeaths
,CAST(ROUND(CAST(SUM(CAST(new_deaths AS INT)) AS FLOAT)/CAST(SUM(CAST(New_Cases AS INT)) AS FLOAT) * 100, 2) AS VARCHAR(5)) + '%' AS DeathPercentage -- Converted from VARCHAR to INT, then to FLOAT to ensure accurate division
FROM staging_data.dbo.tb_covid_deaths
WHERE 1=1
--AND location = 'Canada'
AND continent IS NOT NULL
--GROUP BY date
ORDER BY 1,2
--
-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine
--
SELECT 
 dea.continent
,dea.location
,dea.date
,dea.population
,vac.new_vaccinations
,SUM(CONVERT(INT,vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS TotalPeopleVaccinated
--,(RollingPeopleVaccinated/population)*100 -> Calculated Later on
FROM staging_data.dbo.tb_covid_deaths dea
INNER JOIN staging_data.dbo.tb_covid_vaccinations vac ON (dea.location = vac.location) AND (dea.date = vac.date)
WHERE 1=1
AND dea.continent IS NOT NULL
ORDER BY 2,3
--
-- Using CTE to calculate cumulative vaccinations by country
--
With Peoplevsvaccinations (Continent, Location, Date, Population, New_Vaccinations, TotalPeopleVaccinated)
AS
(
SELECT
 dea.continent
,dea.location
,dea.date
,NULLIF(dea.population, 0) AS population
,vac.new_vaccinations
,SUM(CONVERT(INT,vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS TotalPeopleVaccinated
FROM staging_data.dbo.tb_covid_deaths dea
INNER JOIN staging_data.dbo.tb_covid_vaccinations vac ON (dea.location = vac.location) AND (dea.date = vac.date)
WHERE 1=1
AND dea.continent IS NOT NULL
AND dea.continent <> ''
)
SELECT *
,CAST(ROUND((TotalPeopleVaccinated/CAST(Population AS FLOAT)) * 100, 2) AS VARCHAR(10)) + '%' AS PercentagePopulationVaccinated
FROM Peoplevsvaccinations
ORDER BY 1 ASC
--
-- Using Temp Table to calculate the same result (percentage of population vaccinated)
--
DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(
Continent nvarchar(50),
Location nvarchar(80),
Date datetime,
Population numeric,
new_vaccinations numeric,
TotalPeopleVaccinated numeric
)
--
-- Inserting data into Temp Table
--
INSERT INTO #PercentPopulationVaccinated
SELECT
 dea.continent
,dea.location
,dea.date
,NULLIF(TRY_CAST(dea.population AS NUMERIC), 0) AS population
,TRY_CAST(vac.new_vaccinations AS NUMERIC) AS new_vaccinations
,SUM(CONVERT(INT,vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS TotalPeopleVaccinated
FROM staging_data.dbo.tb_covid_deaths dea
INNER JOIN staging_data.dbo.tb_covid_vaccinations vac ON (dea.location = vac.location) AND (dea.date = vac.date)
WHERE 1=1
AND dea.continent IS NOT NULL
AND dea.continent <> ''
--
-- Selecting final result from Temp Table #PercentPopulationVaccinated
--
SELECT *
,CAST(ROUND((TotalPeopleVaccinated/CAST(Population AS FLOAT)) * 100, 2) AS VARCHAR(10)) + '%' AS PercentagePopulationVaccinated
FROM #PercentPopulationVaccinated
ORDER BY 1 ASC
--
-- Creating a view to store the data for future visualizations
--
DROP VIEW IF EXISTS vw_PercentPopulationVaccinated -- Dropping the view if it already exists
--
CREATE VIEW vw_PercentPopulationVaccinated AS
SELECT
 dea.continent
,dea.location
,dea.date
,NULLIF(TRY_CAST(dea.population AS NUMERIC), 0) AS population
,TRY_CAST(vac.new_vaccinations AS NUMERIC) AS new_vaccinations
,SUM(CONVERT(INT,vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS TotalPeopleVaccinated
FROM staging_data.dbo.tb_covid_deaths dea
INNER JOIN staging_data.dbo.tb_covid_vaccinations vac ON (dea.location = vac.location) AND (dea.date = vac.date)
WHERE 1=1
AND dea.continent IS NOT NULL
AND dea.continent <> '';
--
-- Viewing the data stored in the created view
--
SELECT * 
FROM vw_PercentPopulationVaccinated
ORDER BY 1 ASC

