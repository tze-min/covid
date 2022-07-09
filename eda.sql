-- select data of interest
SELECT
	location, date, total_cases, new_cases, total_deaths, population
FROM Coronavirus.dbo.Death
ORDER BY 1, 2

-- total cases vs total deaths: likelihood of dying if you contract Covid in Singapore
SELECT
	location, date, total_cases, total_deaths
	, CAST(total_deaths AS FLOAT) * 100 / CAST(total_cases AS FLOAT) AS death_rate
FROM Coronavirus.dbo.Death
WHERE location = 'Singapore'
ORDER BY 1, 2

-- total cases vs population: percentage of country's population that caught Covid
SELECT
	location, date, total_cases, population
	, CAST(total_cases AS FLOAT) * 100 / CAST(population AS FLOAT) AS case_rate
FROM Coronavirus.dbo.Death
WHERE location = 'Singapore'
ORDER BY 1, 2

-- countries with the highest cases per population: highest infection rate per country
SELECT
	location, population
	, MAX(total_cases) AS highest_cases
	, CAST(MAX(total_cases) AS FLOAT) * 100 / CAST(population AS FLOAT) AS highest_case_rate
FROM Coronavirus.dbo.Death
GROUP BY location, population
ORDER BY highest_case_rate DESC

-- countries with the highest death count: highest death counts per country
SELECT
	location, population
	, MAX(total_deaths) AS highest_deaths
FROM Coronavirus.dbo.Death
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY highest_deaths DESC

-- continents with the highest death count: highest death counts per continent (version 1)
SELECT
	location
	, MAX(total_deaths) AS highest_deaths
FROM Coronavirus.dbo.Death
WHERE continent IS NULL
GROUP BY location
ORDER BY highest_deaths DESC

-- continents with the highest death count: highest death counts per continent (version 2, strangely different from version 1)
SELECT
	continent
	, MAX(total_deaths) AS highest_deaths
FROM Coronavirus.dbo.Death
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY highest_deaths DESC
GO

-- global death rate TABLEAU
SELECT 
	SUM(new_cases) AS total_cases
	, SUM(new_deaths) AS total_deaths
	, SUM(CAST(new_deaths AS FLOAT)) / SUM(CAST(new_cases AS FLOAT)) AS death_rate
FROM Coronavirus.dbo.Death
WHERE continent IS NOT NULL
GO

-- total death count by continent (as stated in location column) TABLEAU
SELECT
	location
	, SUM(new_deaths) AS total_death_count
FROM Coronavirus.dbo.Death
WHERE 
	continent IS NULL
	AND location NOT LIKE '%income%'
	AND location NOT IN ('World', 'European Union', 'International')
GROUP BY location
GO

-- percentage of population infected per location; changing null values to 0 so that the variables are read as int, not str, in Tableau; TABLEAU
SELECT
	location
	, ISNULL(population, 0) AS population
	, MAX(ISNULL(total_cases, 0)) AS highest_infection_count
	, MAX(ISNULL(CAST(total_cases AS FLOAT) * 100 / CAST(population AS FLOAT), 0)) AS percent_population_infected
FROM Coronavirus.dbo.Death
GROUP BY location, population
ORDER BY percent_population_infected DESC
GO

-- percentage of population infected per location per date; changing null values to 0 so that the variables are read as int, not str, in Tableau; TABLEAU
SELECT
	location, date
	, ISNULL(population, 0) AS population
	, MAX(ISNULL(total_cases, 0)) AS highest_infection_count
	, MAX(ISNULL(CAST(total_cases AS FLOAT) * 100 / CAST(population AS FLOAT), 0)) AS percent_population_infected
FROM Coronavirus.dbo.Death
GROUP BY location, population, date
ORDER BY percent_population_infected DESC
GO

--joining deaths and vaccinations
SELECT
	d.continent, d.location, d.date, d.population, v.new_vaccinations
	, SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS rolling_vaccinated -- can't further transform this column
FROM Coronavirus.dbo.Death d
JOIN Coronavirus.dbo.Vaccination v
	ON d.location = v.location
	AND d.date = v.date
WHERE d.continent IS NOT NULL
ORDER BY 2, 3

--therefore, create CTE
WITH 
	pop_vs_vac (continent, location, date, population, new_vaccinations, rolling_vaccinated)
AS (
	SELECT
		d.continent, d.location, d.date, d.population, v.new_vaccinations
		, SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS rolling_vaccinated
	FROM Coronavirus.dbo.Death d
	JOIN Coronavirus.dbo.Vaccination v
		ON d.location = v.location
		AND d.date = v.date
	WHERE d.continent IS NOT NULL
	AND d.location = 'Singapore'
)
SELECT 
	*
	, CAST(rolling_vaccinated AS FLOAT) * 100 / CAST(population AS FLOAT) AS rolling_vaccinated_rate
FROM pop_vs_vac

GO

-- create view
CREATE VIEW PopulationVaccinated 
AS
	SELECT
		d.continent, d.location, d.date, d.population, v.new_vaccinations
		, SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS rolling_vaccinated
	FROM Coronavirus.dbo.Death d
	JOIN Coronavirus.dbo.Vaccination v
		ON d.location = v.location
		AND d.date = v.date
	WHERE d.continent IS NOT NULL
GO

SELECT 
	*
FROM PopulationVaccinated
