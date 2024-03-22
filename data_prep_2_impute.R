# Data preparation for further analysis (part 2 of 4)

# Author: kirilboyanovbg[at]gmail.com
# Last meaningful update: 21-03-2024

# In this script, we import already pre-cleaned data that contains some missing
# values and use a random forest algorithm to fill in the gaps so that we have
# complete historical data for all municipalities and years. This also includes
# making predictions as we use the same algorithm for filling in the blanks in
# both historical data and future time periods.


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


# Custom function to impute/predict disposable income ====

PredictIncomeForMncp <-
  function(PersonalIncomeAfterTax_Wide,
           MacroDataIMF,
           SelectedMncp) {
    #! This function predicts disposable income (total, men and women) for
    #! a specific municipality (SelectedMncp).
    
    # Getting the first year in the data where income is available
    FirstYearWithIncome <- min(PersonalIncomeAfterTax_Wide$Year)
    
    # Getting the first year where no income data is available
    FirstYearNoIncome <- max(PersonalIncomeAfterTax_Wide$Year) + 1
    
    # Filtering the data
    FilteredData <- PersonalIncomeAfterTax_Wide %>%
      filter(Municipality == SelectedMncp)
    
    # Adding macroeconomic data
    MncpData <- MacroDataIMF %>%
      left_join(FilteredData, by = "Year") %>%
      filter(Year >= FirstYearWithIncome) %>%
      fill(Municipality, .direction = "down")
    
    # Fitting linear regression models for the variables we'd like to impute
    ModelTotal <- lm("AvgDisposableIncomeTotal ~ GDP", MncpData)
    ModelMen <- lm("AvgDisposableIncomeMen ~ GDP", MncpData)
    ModelWomen <- lm("AvgDisposableIncomeWomen ~ GDP", MncpData)
    
    # Generating imputations/predictions for the selected variables
    MncpData <- MncpData %>%
      mutate(
        AvgDisposableIncomeTotal_Pred = predict(ModelTotal, MncpData),
        AvgDisposableIncomeMen_Pred = predict(ModelMen, MncpData),
        AvgDisposableIncomeWomen_Pred = predict(ModelWomen, MncpData)
      )
    
    # Calculating the absolute % error
    MncpData <- MncpData %>%
      mutate(
        AbsPctErrorTotal = (AvgDisposableIncomeTotal_Pred - AvgDisposableIncomeTotal) /
          AvgDisposableIncomeTotal,
        AbsPctErrorMen = (AvgDisposableIncomeMen_Pred - AvgDisposableIncomeMen) /
          AvgDisposableIncomeMen,
        AbsPctErrorWomen = (AvgDisposableIncomeWomen_Pred - AvgDisposableIncomeWomen) /
          AvgDisposableIncomeWomen,
        AbsPctErrorTotal = abs(AbsPctErrorTotal),
        AbsPctErrorMen = abs(AbsPctErrorMen),
        AbsPctErrorWomen = abs(AbsPctErrorWomen)
      )
    
    # Recording the R squared for the models used to impute/predict values
    MncpData <- MncpData %>%
      mutate(
        ModelR2_Total = summary(ModelTotal)$r.squared,
        ModelR2_Men = summary(ModelMen)$r.squared,
        ModelR2_Women = summary(ModelWomen)$r.squared
      )
    
    # Recording the MAPE scores for the models
    MAPE_Total <- mean(MncpData$AbsPctErrorTotal, na.rm = TRUE)
    MAPE_Men <- mean(MncpData$AbsPctErrorMen, na.rm = TRUE)
    MAPE_Women <- mean(MncpData$AbsPctErrorWomen, na.rm = TRUE)
    MncpData <- MncpData %>%
      mutate(
        ModelMAPE_Total = MAPE_Total,
        ModelMAPE_Men = MAPE_Men,
        ModelMAPE_Women = MAPE_Women
      )
    
    # Combining historical data with predictions
    MncpData <- MncpData %>%
      mutate(
        AvgDisposableIncomeTotal = ifelse(
          is.na(AvgDisposableIncomeTotal),
          AvgDisposableIncomeTotal_Pred,
          AvgDisposableIncomeTotal
        ),
        AvgDisposableIncomeMen = ifelse(
          is.na(AvgDisposableIncomeMen),
          AvgDisposableIncomeMen_Pred,
          AvgDisposableIncomeMen
        ),
        AvgDisposableIncomeWomen = ifelse(
          is.na(AvgDisposableIncomeWomen),
          AvgDisposableIncomeWomen_Pred,
          AvgDisposableIncomeWomen
        ),
        ObservationType = ifelse(Year < FirstYearNoIncome, "Historical data", "Prediction")
      )
    
    # Returning only relevant columns
    ColsToKeep <-
      c(
        "Year",
        "Municipality",
        "ObservationType",
        "AvgDisposableIncomeTotal",
        "AvgDisposableIncomeMen",
        "AvgDisposableIncomeWomen",
        "ModelR2_Total",
        "ModelR2_Men",
        "ModelR2_Women",
        "ModelMAPE_Total",
        "ModelMAPE_Men",
        "ModelMAPE_Women"
      )
    MncpData <- MncpData %>%
      select(all_of(ColsToKeep))
    
    return(MncpData)
  }


# Importing already cleaned data ====

# Data on sales prices of flats
OwnFlatAnnualPrices <-
  read_parquet("Temp data/OwnFlatAnnualPrices.parquet")

# Data on disposable income
PersonalIncomeAfterTax_Wide <-
  read_parquet("Temp data/PersonalIncomeAfterTax_Wide.parquet")

# Macroeconomic indicators
MacroDataIMF <- read_parquet("Temp data/MacroDataIMF.parquet") %>%
  select(-ObservationType)
AnnualInterestRate <-
  read_parquet("Temp data/AnnualInterestRate.parquet")


# Imputing for missing values in disposable income data ====
# Note: this includes generating predictions for future income for as long as
# we have external predictions on GDP (from the IMF).

# Unique municipalities to loop over
UniqueMncp <- unique(PersonalIncomeAfterTax_Wide$Municipality)

# We loop over all municipalities to generate income data for future
# time periods (separate models are fit for total income, male & female income)
ImputedIncomeData <- data.frame()
for (mncp in UniqueMncp) {
  MncpData <-
    PredictIncomeForMncp(PersonalIncomeAfterTax_Wide, MacroDataIMF, mncp)
  ImputedIncomeData <- rbind(ImputedIncomeData, MncpData)
}

# Creating a separate df with the model fit metrics
# Note: R2 and MAPE will be converted to %
IncomeModelFitMetrics <- ImputedIncomeData %>%
  select(
    Municipality,
    ModelR2_Total,
    ModelR2_Men,
    ModelR2_Women,
    ModelMAPE_Total,
    ModelMAPE_Men,
    ModelMAPE_Women
  ) %>%
  distinct(Municipality, .keep_all = TRUE) %>%
  mutate(PctAccuracy_Total = 1 - ModelMAPE_Total,
         PctAccuracy_Men = 1 - ModelMAPE_Men,
         PctAccuracy_Women = 1- ModelMAPE_Women) %>%
  mutate_if(is.numeric, ~ round(. * 100, 1))


# Putting different kinds of data together for imputation & prediction ====

# Defining which years we want to keep: min is the first year of sales data,
# while max is the last year with income-related/macroeconomic data
MinYear <- min(OwnFlatAnnualPrices$Year)
MaxYear <- max(ImputedIncomeData$Year)
RelevantYears <- c(MinYear:MaxYear)

# Defining which municipalities to include in the data
UniqueMncp <- unique(OwnFlatAnnualPrices$Municipality)

# Creating a placeholder dataset with 1 row per year and municipality
PlaceholderDf <- data.frame()
for (mncp in UniqueMncp) {
  TempData <- as.data.frame(RelevantYears)
  names(TempData) <- c("Year")
  TempData$Municipality <- mncp
  PlaceholderDf <- rbind(PlaceholderDf, TempData)
}

# Adding sales data, income data and macroeconomic data to the placeholder
PlaceholderDf <- PlaceholderDf %>%
  left_join(OwnFlatAnnualPrices, by = c("Year", "Municipality")) %>%
  left_join(ImputedIncomeData, by = c("Year", "Municipality")) %>%
  left_join(MacroDataIMF, by = "Year") %>%
  left_join(AnnualInterestRate, by = "Year") %>%
  select(-Region)

# Creating national disposable income and relative disposable income columns
PlaceholderDf <- PlaceholderDf %>%
  group_by(Year) %>%
  mutate(
    NationalDisposableTotalAvg = mean(AvgDisposableIncomeTotal, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(LocalIncomeRelToNational = AvgDisposableIncomeTotal/NationalDisposableTotalAvg)


# Splitting placeholder data into historical & future data ====

# Defining which years to use in the imputation dataset
# Note: we only want to use the random forest imputer on historical data
MostRecentSalesYear <- max(OwnFlatAnnualPrices$Year)

# Creating a filtered df containing historical data
DataForImputer <- PlaceholderDf %>%
  filter(Year <= MostRecentSalesYear)

# Creating a filtered placeholder for future periods
DataForPrediction <- PlaceholderDf %>%
  filter(Year > MostRecentSalesYear)


# Imputing for missing values in sales price data ====

# Keeping only relevant columns
ColsToKeep <-
  c(
    "Year",
    "Municipality",
    "AvgSalesPrice",
    "AvgDisposableIncomeTotal",
    "AvgDisposableIncomeMen",
    "AvgDisposableIncomeWomen",
    "NationalDisposableTotalAvg",
    "LocalIncomeRelToNational"
  )
DataForImputer <- DataForImputer %>%
  select(any_of(ColsToKeep), TotalSales)

# Adding columns relating the municipality's income level relative to the
# national average (as computed across municipalities)
DataForImputer <- DataForImputer %>%
  group_by(Year) %>%
  mutate(
    NationalTotalSales = sum(TotalSales),
    NationalAvgSalesPrice = mean(AvgSalesPrice, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  filter(!is.na(NationalDisposableTotalAvg)) %>%
  select(-TotalSales) %>%
  mutate(PriceType = ifelse(is.na(AvgSalesPrice), "Estimated price", "Actual price"))

# Excluding string & other irrelevant variables from the imputation process
TempMunicipality <- DataForImputer$Municipality
TempPriceType <- DataForImputer$PriceType
TempIncomeObsType <- DataForImputer$IncomeObsType
DataForImputer$Municipality <- NULL
DataForImputer$PriceType <- NULL
DataForImputer$IncomeObsType <- NULL

# Using missForest to do the imputation and record OOB error estimates
ImputedSalesAndIncome <-
  missForest(as.data.frame(DataForImputer), variablewise = TRUE)

# Getting the mean values of each variable in the input data
MeanValues <- sapply(DataForImputer, mean, na.rm = TRUE)
MeanValues <- data.frame(VariableName = names(DataForImputer), MeanValue = MeanValues)

# Getting the OOB error estimates
ImputationFitMetrics <- ImputedSalesAndIncome$OOBerror

# Consolidating the fit metrics in a data frame format
ImputationFitMetrics <- as.data.frame(ImputationFitMetrics)
names(ImputationFitMetrics) <- c("ModelMSE")
ImputationFitMetrics$VariableName <- names(as.data.frame(DataForImputer))
ImputationFitMetrics <- ImputationFitMetrics %>%
  select(VariableName, ModelMSE) %>%
  left_join(MeanValues, by = "VariableName") %>%
  mutate(ModelRMSE = sqrt(ModelMSE),
         ModelNormalizedRMSE = ModelRMSE/MeanValue,
         PctAccuracy = 1 - ModelNormalizedRMSE) %>%
  mutate(ModelNormalizedRMSE = round(100 * ModelNormalizedRMSE, 1),
         PctAccuracy = round(100 * PctAccuracy, 1))

# Converting the results back to a data frame and adding string columns back
ImputedSalesAndIncome <- ImputedSalesAndIncome$ximp
ImputedSalesAndIncome$Municipality <- TempMunicipality
ImputedSalesAndIncome$PriceType <- TempPriceType
ImputedSalesAndIncome$IncomeObsType <- TempIncomeObsType

# Reordering columns in the original order
ImputedSalesAndIncome <- ImputedSalesAndIncome %>%
  select(Year,
         Municipality,
         PriceType,
         AvgSalesPrice,
         everything())


# Exporting the data for further analysis ====

# Exporting dataset with imputed disposable income data
write_parquet(ImputedIncomeData, "Temp data/ImputedIncomeData.parquet")

# Exporting datasets with historical sales prices and income
write_parquet(ImputedSalesAndIncome,
              "Temp data/ImputedSalesAndIncome.parquet")

# Exporting dataset with the imputation's fit metrics
write_parquet(ImputationFitMetrics, "Output data/SalesPriceImputationFitMetrics.parquet")

# Exporting placeholder dataset for future time periods
write_parquet(DataForPrediction, "Temp data/DataForPrediction.parquet")

# Exporting dataset with model fit metrics for "AvgSalesPrice")
write_parquet(IncomeModelFitMetrics, "Output data/IncomeModelFitMetrics.parquet")

# Printing a notice to the user
print("Note: Data imputation successfully completed.")
print("The data have been successfully exported to the local folders.")
