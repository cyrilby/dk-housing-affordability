[![Streamlit App](https://static.streamlit.io/badges/streamlit_badge_black_white.svg)](https://dk-housing.streamlit.app/)
[![MindGraph](https://img.shields.io/badge/Product%20of%20-MindGraph.dk-1ea2b5?logo=https://mindgraph.dk/favicon.png")](https://mindgraph.dk)

# DK housing affordability

* Author: Kiril (GitHub@cyrilby)
* Website: [mindgraph.dk](https://mindgraph.dk)
* Last meaningful update: 10-04-2025

This repository contains `R` and `Python` code designed to collect, clean and visualize data on housing prices in Denmark. The output of the process is a Streamlit app, which gives users an insight into what sales prices of apartments in different Danish municipalities look like and how affordable buying a flat is.

## Use case scenarios

The focus in here is on both the **sales price** of apartments and their **affordability** (measured in terms of its relation to personal income). The focus in here is on the so-called "owned apartments" (called *ejerbolig* in Danish).

**Using this app, you will be able to find answers to questions such as:**

- How have prices evolved in the past both in general and for each municipality?
- How has housing affordability changed, i.e. comparing pricing to personal income?
- Which are the most and least expensive municipalities in e.g. 2024?
- How will prices and affordability evolve in the next few years based on historical - trends and future projections for macroeconomic development?

The app contains historical housing prices and income statistics spanning across 32 years as well as predictions for future pricing and affordability covering the next 5 years.

## Data sources

All data on prices, GDP and income is in *nominal prices*, which allows for direct comparisons between sales prices and GDP/disposable income.

### Data on sales prices

Data on **prices of owned flats** (*ejerbolig* in Danish) comes from the `BM011` table on [Finans Danmark](http://localhost:8501/rkr.statistikbank.dk) 's website:

- Historical data is available starting from 1992 and up until the end of the most recent complete quarter.
- Originally, the data comes in a quarterly format and is split by post code.
- To transform it for use in this app, the post codes have been grouped into their respective municipalities and the quarterly data has been aggregated on an annual basis.
- When doing the aggregation, we use the simple average for periods prior to 2004 and a weighted average for the year 2004 and thereafter. The weighted average approach improves data quality because it accounts for how many sales took place in each post code and not just their average price, but data on number of sales are not available before 2004, meaning we cannot use a weighted average before that year.
- The price type exported is the *realiseret handelspris*, which means it's based on the final prices at which the flats were sold.
Please note that this data is supplied by data on the number of sold flats in each post code and quarter, which are sourced from the `BM021` table on the [same website](http://localhost:8501/rkr.statistikbank.dk).

### Data on disposable income

Data on average disposable income by municipality is collected from the `INDKP101` table on [Danmarks Statistik (DST)](www.dst.dk)'s website.

- The data comes in an annual format and spans across 1987-2023 as of Arpil 2025 (new data is added in November, 2 years after the fact, i.e. with quite a significant delay).
- The data presents average disposable income in each municipality both in total but also divided by gender (male/female only).
- It is furthermore possible to filter the data by age group and income level interval, however, this has not been deemed necessary for this app.

### Data on macroeconomic indicators

Background data on most **national macroeconomic indicators** was collected from the most recent editions of the IMF's [World Economic Outlook](https://www.imf.org/en/Publications/WEO):

- The data covers the period 1980-2028, where historical data is used until the end of 2022 and where official estimates predictions are used for the remaining time periods.
- The data used specifically in this app are the Gross domestic product measured in nominal prices as well as Inflation, end of period measured in consumer prices.


Data on **interest rate** was collected from the `MPK3` table on Danmarks Statistik (DST)'s website:

- The data is available on a monthly basis starting from 1985 and up until the end of the most recent complete month.
- The data is aggregated at the annual level using its median value.
- The data type downloaded is Nationalbankens diskonto, which is the rate that banks in Denmark use as a starting point as it stems from Denmark's National Bank.

## Methodology

The data presented in this app has been subjected to several different models in order for the app to be able to show e.g. uninterrupted historical data or predictions for the future. Naturally, these models introduce some degree of uncertainty to some of the numbers presented. To increase transparency, the accuracy metrics related to all models applied to the raw data are reported in the app, while the method is described below.

### Predictions for disposable income

DST provides data on disposable income with a significant delay, for example, the data for 2024 will only be published in November 2025. In addition, no data on future disposable income is available in the source but as certain calculations depend on knowing future income levels (e.g. future housing affordability), we need to generate predictions for future disposable income as well.

- Predictions are generated by fitting a separate OLS regression model for each municipality, where local disposable income is modelled as a function of Denmark's national GDP.
- The accuracy of the model is then evaluated using the inverse of the mean absolute percentage error (MAPE) score, which shows by how much the income predicted by the model differs from the observed income in the historical data.
- The R² metric shows how much of the change in local income can be explained by its relationship to Denmark's national GDP.

### Predictions for future sales price

Finans Danmark does not provide predictions for future sales prices, though exploring how historical trends might translate into the future can be a valuable insight. Therefore, additional predictive models were included in here so that we can get an estimate of not only what future sales prices might look like but also what housing affordability might be.

- Predictions are generated by fitting a separate OLS regression model for each municipality, where local average sales price is modelled as a function of Denmark's national GDP, annual inflation and the annual median interest rate as reported by Denmark's national bank.
- The future values of GDP and inflation are sourced from the IMF's World Economic Outlook (published in April and October), while for interest rate, we use the all-time historical average of 3.25%.
- The accuracy of the model is then evaluated using the inverse of the mean absolute percentage error (MAPE) score, which shows by how much the price predicted by the model differs from the observed price in the historical data.
- The R² metric shows how much of the change in sales price can be explained by its relationship to Denmark's national GDP, annual inflation and annual median interest rate.

### Imputations in historical prices

The way Finans Danmark measures sales prices is based on actual sales, however, it is not always the case that sales have been realized in every municipality in each year. Furthermore, sometimes the number of realized sales is too low and Finans Danmark choses not to disclose the price. To be able to show uninterrupted historical data even in cases where no actual sales data is available in the source, a special algorithm was used to generate the approximate sales prices in those cases where they were missing.

- Imputations were made using a random forest algorithm (`missForest`), which was applied across municipalities to ensure prices in any given year were comparable. The algorithm estimated the missing prices based on other known values such as the national average sales price, the total number of sales in the year as well as the local level of disposable income and its relationship with the national level of income.
- The accuracy of the model is then evaluated using the inverse of the normalized root of the mean squared error (RMSE) score, which shows by how much the model's output differs from the observed price in the historical data. This was used as a substitute for the MAPE score as the imputation algorithm (`missForest`) does not provide the latter.

### Notes on the impact of uncertainty
Uncertainty may impact the numbers shown in this app in two main ways:

1. First, because we have some missing data for historical sales prices, we have had to restort to imputing them. Although the algorithm used has provided reasonable values for those cases where they were missing in the source, the real prices in that period are unknown and the model can only provide approximations.
2. Second, because future prices are predicted based on historical trends, these numbers are valid only so far as the assumption that historical trends will continue into the future holds true.

As the numbers may in some cases be impacted by uncertainty, a complete disclosure of the model accuracy has been made.

All in all, while the models applied to transform the data may introduce some uncertainty to the numbers displayed, they also bring about important improvements such as the ability to show continuous historical data for all municipalities as well as the ability to get an idea of what future sales prices might look like.