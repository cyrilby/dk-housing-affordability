# Input data sourcing for the project

## Data on prices of owned flats [complete]

This data comes from the `BM011` table and is collected manually from the [rkr.statistikbank.dk](rkr.statistikbank.dk) website. Due to only being able to export a limited number of cells at the same time, the data is split into several different files, including:

* BM011 1992-1999.xlsx
* BM011 2000-2005.xlsx
* BM011 2006-2012.xlsx
* BM011 2013-2019.xlsx
* BM011 2020-2023.xlsx

The data comes in a **quarterly format** but can be aggregated to annual to include the mean or median price. The price type exported is "realiseret handelspris".

## Data on number of sold owned flats [complete]

The data comes from the `BM021` table and is collected manually from the [rkr.statistikbank.dk](rkr.statistikbank.dk) website. Due to only being able to export a limited number of cells at the same time, the data is split into several different files, including:

* BM021 2004-2011.xlsx
* BM021 2011-2019.xlsx
* BM021 2020-2023.xlsx

The data comes in a **quarterly format** and can be used in conjuction with the sales prices data (also from the same source) in order to calculate more meaningful means for different municipalities (e.g. weighted average). The latter is, however, only possible starting from 2004 since no data is available prior to that point.

## Data on prices of renting [not started]

This could be either renting from public housing associations ("almen bolig") or renting on the private market. Initial assessment of search results shows this data may be a lot more difficult to obtain relative to data on sales prices.

## Population data

### Average disposable income [complete]

Data on average disposable income by muncipality is sourced from the `INDKP106` table provided by [Statistics Denmark](www.dst.dk) and is saved to the "INDKP106" files. One of the files contains the number of people, the other one contains the average disposable income in the respective year.

### 2023 data not yet available

After the numbers appear on [DST's webiste](https://www.statistikbanken.dk/INDKP106) becomes available, it would make sense to update it in the source, too. However, according to the official information, the data will not be updated before (!!!) November 2024, so it doesn't make sense to wait for it:

```
TABELINFORMATION

Tabellen er senest opdateret: 27-11-2023 08:00
Opdateres næste gang: 13-11-2024 08:00 med perioden 2023
```

The app development can be continued without having to wait for this data to become available.

### Distribution of people into income brackets [not started]

Data on average disposable income by muncipality & income bracket is sourced from the `INDKP106` table provided by [Statistics Denmark](www.dst.dk) and is saved to the "INDKP106.xlsx" file.

With it, it is possible to measure the number of m2 that people in the lowest income bracket could buy and relate it to the corresponding number that people in the highest income bracket could buy.

### Average disposable household income in different income brackets [complete]

Data on average disposable income among households is sourced from the `INDKF132` table provided by [Statistics Denmark](www.dst.dk) and is saved to the "INDKF132.xlsx" file.

## Macroeconomic data

### Wealth stored in real estate [complete]

Data on the number of different property types and their average market values comes from the `EJDFOE1` table provided by [Statistics Denmark](www.dst.dk) and is saved to the "EJDFOE1.xlsx" file.

### National macroeconomic statistics [complete]

Data on national metrics such as GDP, inflation, unemployment etc. is sourced from the `NAN1` table provided by [Statistics Denmark](www.dst.dk) and is saved to the "NAN1.xlsx" file.

## Supplementary tables

### Mapping of Danish post numbers to municipalities [complete]

The mapping is downloaded from [this GitHub project](https://github.com/zauberware/postal-codes-json-xml-csv), which provides data on ZIP codes for many different countries. Using this mapping, it's possible to connect the sales data (which is separated by post number) 