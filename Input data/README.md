# Input data sourcing for the project

## Data on prices of owned flats

This data comes from the `BM011` table and is collected manually from the [rkr.statistikbank.dk](rkr.statistikbank.dk) website. Due to only being able to export a limited number of cells at the same time, the data is split into several different files, including:

* BM011 1992-1999.xlsx
* BM011 2000-2005.xlsx
* BM011 2006-2012.xlsx
* BM011 2013-2019.xlsx
* BM011 2020-2024.xlsx

The data comes in a **quarterly format** but can be aggregated to annual to include the mean or median price. The price type exported is "realiseret handelspris".

## Data on number of sold owned flats [complete]

The data comes from the `BM021` table and is collected manually from the [rkr.statistikbank.dk](rkr.statistikbank.dk) website. Due to only being able to export a limited number of cells at the same time, the data is split into several different files, including:

* BM021 2004-2011.xlsx
* BM021 2011-2019.xlsx
* BM021 2020-2024.xlsx

The data comes in a **quarterly format** and can be used in conjuction with the sales prices data (also from the same source) in order to calculate more meaningful means for different municipalities (e.g. weighted average). The latter is, however, only possible starting from 2004 since no data is available prior to that point.

## Data on prices of renting [not started]

This could be either renting from public housing associations ("almen bolig") or renting on the private market. Initial assessment of search results shows this data may be a lot more difficult to obtain relative to data on sales prices.

## Population data

The only metric related to population that we use in this project is related to average personal disposable income, particularly the following table: 

* `INDKP101`: data on disposable income for each municipality for each year (it is available with a 1-year delay, i.e. in 2025, the latest complete data are as of the end of 2023)

New data can be downloaded from the [DST website](https://www.statistikbanken.dk/statbank5a/default.asp?w=1185).

## Macroeconomic data

### IMF WEO data

The main source of macroeconomic data is the World Economic Outlook (WEO), which is published twice a year (once in April and once in October). The WEO contains dta on e.g. GDP, inflation and interest rates as well as population, and contains forecasts for the upcoming 5 years for most of these indicators.

New IMF WEO data can be downloaded [from here](https://www.imf.org/en/Publications/WEO).

### Interest rate data

Although interest rates for future time periods are available in the IMF WEO data, they are only available on an annual basis. Therefore, for the historical data, we use Danmarks Statistik as a source for quarterly interest rates, specifically the following table:

* `MPK3`: data on the interest rate of Denmark's National Bank, available for each month

New data can be downloaded from the [DST website](https://www.statistikbanken.dk/statbank5a/default.asp?w=1185).

## Supplementary tables

### Mapping of Danish post numbers to municipalities

The mapping is downloaded from [this GitHub project](https://github.com/zauberware/postal-codes-json-xml-csv), which provides data on ZIP codes for many different countries. Using this mapping, it's possible to connect the sales data (which is separated by post number) 