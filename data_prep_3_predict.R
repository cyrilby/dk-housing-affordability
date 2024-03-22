# Data preparation for further analysis (part 3 of 4)

# Author: kirilboyanovbg[at]gmail.com
# Last meaningful update: 21-03-2024

# In this script, we import clean historical data on sales and income where
# any gaps in the data have been filled with imputed values as well as a df
# containing placeholder rows for future time periods. Then, we use a series
# of municipality-level models to predict future sales prices.


# Setting things up ====

# Importing relevant packages
library(tidyverse)
library(arrow)
library(zoo)
library(stringr)
library(filesstrings)
library(missForest)
library(corrr)

# Specifying local storage folder
AnalysisFolder <-
  "C:/Users/Documents/Hsng prices/"
setwd(AnalysisFolder)

# Custom function to predict "AvgSalesPrice" by municipality ====

PredictPriceForMncp <-
  function(HistoricalSales,
           FutureSales,
           N_Years_Historical,
           SelectedMncp) {
    # Filtering the data
    # Note: we limit the historical data to the last N years
    # only to improve model accuracy
    FilteredHistorical <- HistoricalSales %>%
      filter(Municipality == SelectedMncp)
    FilteredHistoricalForModel <- FilteredHistorical %>%
      filter(Year >= max(Year) - N_Years_Historical)
    FilteredFuture <- FutureSales %>%
      filter(Municipality == SelectedMncp)
    
    # Fitting a linear regression model
    # Note: "LocalIncomeRelToNational" removed from model to test its impact
    # as predictions for e.g. "Holstebro" were way off...
    ModelForPrice <-
      lm(
        "AvgSalesPrice ~ GDP + AnnualInflation + MedianInterestRate",
        FilteredHistoricalForModel
      )
    
    # Predicting for the historical period and calculating abs % error
    FilteredHistoricalForModel <- FilteredHistoricalForModel %>%
      mutate(PredictedSalesPrice = predict(ModelForPrice, FilteredHistoricalForModel)) %>%
      mutate(
        AbsPctError = (PredictedSalesPrice - AvgSalesPrice) / AvgSalesPrice,
        AbsPctError = abs(AbsPctError)
      ) %>%
      select(Year,
             Municipality,
             AvgSalesPrice,
             PredictedSalesPrice,
             everything())
    
    # Recording MAPE score and R2
    MAPE_Score <- mean(FilteredHistoricalForModel$AbsPctError)
    ModelR2_Score <- summary(ModelForPrice)$r.squared
    
    # Predicting for future time periods
    FilteredFuture <- FilteredFuture %>%
      mutate(AvgSalesPrice = predict(ModelForPrice, FilteredFuture)) %>%
      select(Year, Municipality, AvgSalesPrice, everything())
    
    # Combining historical data and predictions in a single df
    OutputData <-
      plyr::rbind.fill(FilteredHistorical, FilteredFuture) %>%
      mutate(ModelMAPE_SalesPrice = MAPE_Score,
             ModelR2_SalesPrice = ModelR2_Score)
    
    return(OutputData)
  }


# Importing already cleaned data ====

# Importing historical data with no missing values remaining
HistoricalSales <-
  read_parquet("Temp data/ImputedSalesAndIncome.parquet")

# Importing placeholder rows for future time periods
FutureSales <- read_parquet("Temp data/DataForPrediction.parquet")

# Macroeconomic indicators
MacroDataIMF <- read_parquet("Temp data/MacroDataIMF.parquet") %>%
  select(-ObservationType)
AnnualInterestRate <-
  read_parquet("Temp data/AnnualInterestRate.parquet")

# Adding macroeconomic data to the historical sales data
MacroDataIMF <- MacroDataIMF %>%
  select(Year, AnnualInflation, GDP)
HistoricalSales <- HistoricalSales %>%
  left_join(MacroDataIMF, by = "Year") %>%
  left_join(AnnualInterestRate, by = "Year")


# Automatically predicting future sales prices for each municipality ====

# Unique municipalities to loop over
UniqueMncp <- unique(HistoricalSales$Municipality)

# We loop over all municipalities to generate income data for future periods
# Note: we base our models on the last 20 years of data to improve their accuracy
PredictedSalesAndIncome <- data.frame()
for (mncp in UniqueMncp) {
  MncpData <-
    PredictPriceForMncp(HistoricalSales, FutureSales, 20, mncp)
  PredictedSalesAndIncome <- rbind(PredictedSalesAndIncome, MncpData)
}


# Formatting and exporting the data ====

# Ensuring we have all columns required by the Streamlit app
# and that we have no missing values in them

# Marking rows containing predictions
PredictedSalesAndIncome <- PredictedSalesAndIncome %>%
  mutate(PriceType = ifelse(is.na(PriceType), "Predicted price", PriceType))

# Creating a separate df with the model fit metrics
SalesModelFitMetrics <- PredictedSalesAndIncome %>%
  select(Municipality, ModelR2_SalesPrice, ModelMAPE_SalesPrice) %>%
  distinct(Municipality, .keep_all = TRUE) %>%
  mutate(PctAccuracy_SalesPrice = 1 - ModelMAPE_SalesPrice) %>%
  mutate_if(is.numeric, ~ round(. * 100, 1))

# Exporting dataset with final predictions
write_parquet(PredictedSalesAndIncome, "Temp data/PredictedSalesAndIncome.parquet")

# Exporting dataset with model fit metrics for "AvgSalesPrice")
write_parquet(SalesModelFitMetrics, "Output data/SalesModelFitMetrics.parquet")

# Printing a notice to the user
print("Note: Predicting future sales prices successfully completed.")
print("The data have been successfully exported to the local folder.")
