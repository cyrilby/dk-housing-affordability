# Data preparation for further analysis (part 1 of 4)

# Author: kirilboyanovbg[at]gmail.com
# Last meaningful update: 01-04-2025

# In this script, we import data from different sources and perform some
# clean-up that allows us to later integrate the data into a single dataset,
# which we can then use for analytic purposes.


# Setting things up ====

# Importing relevant packages
library(tidyverse)
library(arrow)
library(openxlsx)
library(readxl)
library(zoo)
library(stringr)
library(filesstrings)

# Specifying uppercase spellings in the data to be corrected
SpellingToFix = c("FAST EJENDOM I ALT")


# Mapping table for post numbers and municipalities ====
# Source: GitHub

# Importing, correcting data types and keeping relevant columns only
MappingTable <- read_csv("Input data/Danish postnumbers.csv") %>%
  mutate(zipcode = as.numeric(zipcode)) %>%
  select(zipcode, province, state) %>%
  distinct(zipcode, .keep_all = TRUE)

# Assigning proper names
names(MappingTable) <- c("PostCode", "Municipality", "Region")

# Removing unnecessary sub-strings
MappingTable <- MappingTable %>%
  mutate(
    Municipality = gsub(" Kommune", "", Municipality),
    Municipality = gsub("Københavns", "København", Municipality),
    Region = gsub("Region ", "", Region)
  )


# Quarterly sales prices of owned flats ====
# Source: RKR/Finans Danmark

# Getting a list of relevant files
RelevantFiles <- list.files(path = "Input data/")
RelevantFiles <-
  RelevantFiles[str_detect(RelevantFiles, "BM011")]

# Data frame to store the entirety of the data
OwnFlatPrices <- data.frame()

# Looping through all relevant files
for (File in RelevantFiles) {
  TempData <-
    read_excel(paste("Input data/", File, sep = ""), skip = 2) # importing
  TempData <- TempData[, -c(1, 2)] # dropping superfluous columns
  colnames(TempData)[1] <- "Location" # assigning proper name
  ColsWithPeriods <-
    colnames(TempData)[2:length(colnames(TempData))] # identifying values
  TempData <- TempData %>% # converting to the long format
    pivot_longer(
      cols = any_of(ColsWithPeriods),
      names_to = "YearQuarter",
      values_to = "AvgPricePerSquareMeter"
    )
  OwnFlatPrices <-
    plyr::rbind.fill(OwnFlatPrices, TempData) # appending to main df
}

# Sorting, then adding proper columns for post number, year and quarter
OwnFlatPrices <- OwnFlatPrices %>%
  arrange(Location, YearQuarter) %>%
  mutate(Year = str_sub(YearQuarter, 1, 4),
         Quarter = str_sub(YearQuarter, 6, 6)) %>%
  mutate(
    YearQuarter = paste(Year, " Q", Quarter, sep = ""),
    PostCode = str_sub(Location, 1, 4),
    DoublePostCode = str_sub(Location, 5, 5)
  ) %>%
  mutate(
    DoublePostCode = (DoublePostCode == "-"),
    Location = ifelse(
      DoublePostCode,
      str_sub(Location, 11, -1L),
      str_sub(Location, 6, -1L)
    )
  ) %>%
  select(-DoublePostCode)

# Converting the price to numeric (this will create some missing values)
# Note: we also replace 0 with NAN as we assume those are errors in the data
OwnFlatPrices <- OwnFlatPrices %>%
  mutate(
    AvgPricePerSquareMeter = as.numeric(AvgPricePerSquareMeter),
    AvgPricePerSquareMeter = ifelse(AvgPricePerSquareMeter <= 0, NA, AvgPricePerSquareMeter),
    Year = as.numeric(Year),
    Quarter = as.numeric(Quarter),
    PostCode = as.numeric(PostCode)
  )

# Reordering columns
OwnFlatPrices <- OwnFlatPrices %>%
  select(PostCode,
         Location,
         YearQuarter,
         Year,
         Quarter,
         AvgPricePerSquareMeter)


# Quarterly number of sales of owned flats ====
# Source: RKR/Finans Danmark

# Getting a list of relevant files
RelevantFiles <- list.files(path = "Input data/")
RelevantFiles <-
  RelevantFiles[str_detect(RelevantFiles, "BM021")]

# Data frame to store the entirety of the data
OwnFlatSales <- data.frame()

# Looping through all relevant files
for (File in RelevantFiles) {
  TempData <-
    read_excel(paste("Input data/", File, sep = ""), skip = 2) # importing
  TempData <- TempData[, -c(1, 2)] # dropping superfluous columns
  colnames(TempData)[1] <- "Location" # assigning proper name
  ColsWithPeriods <-
    colnames(TempData)[2:length(colnames(TempData))] # identifying values
  TempData[] <-
    lapply(TempData, as.character) # ensuring all data types are the same
  TempData <- TempData %>% # converting to the long format
    pivot_longer(
      cols = any_of(ColsWithPeriods),
      names_to = "YearQuarter",
      values_to = "NumberOfSales"
    )
  OwnFlatSales <-
    plyr::rbind.fill(OwnFlatSales, TempData) # appending to main df
}

# Sorting, then adding proper columns for post number, year and quarter
OwnFlatSales <- OwnFlatSales %>%
  arrange(Location, YearQuarter) %>%
  mutate(Year = str_sub(YearQuarter, 1, 4),
         Quarter = str_sub(YearQuarter, 6, 6)) %>%
  mutate(
    YearQuarter = paste(Year, " Q", Quarter, sep = ""),
    PostCode = str_sub(Location, 1, 4),
    DoublePostCode = str_sub(Location, 5, 5)
  ) %>%
  mutate(
    DoublePostCode = (DoublePostCode == "-"),
    Location = ifelse(
      DoublePostCode,
      str_sub(Location, 11, -1L),
      str_sub(Location, 6, -1L)
    )
  ) %>%
  select(-DoublePostCode)

# Converting data types to numeric (this will create some missing values)
OwnFlatSales <- OwnFlatSales %>%
  mutate(
    NumberOfSales = as.numeric(NumberOfSales),
    Year = as.numeric(Year),
    Quarter = as.numeric(Quarter),
    PostCode = as.numeric(PostCode)
  )

# Reordering columns
OwnFlatSales <- OwnFlatSales %>%
  select(PostCode, Location, YearQuarter, Year, Quarter, NumberOfSales)


# Personal disposable income by year and municipality ====
# Source: DST (Table: INDKP101)

# Reading file exported from DST
PersonalIncomeAfterTax <-
  read_excel("Input data/INDKP101.xlsx",
             skip = 2)

# Repairing column names
ColNames <- names(PersonalIncomeAfterTax)
ColWithYears <- ColNames[5:length(ColNames)]
ColNames <-
  append(c("Meta1", "Meta2", "Gender", "Municipality"),
         ColWithYears)
names(PersonalIncomeAfterTax) <- ColNames

# Repairing metric names: forward filling and removing footnotes
PersonalIncomeAfterTax <- PersonalIncomeAfterTax %>%
  fill(Gender, Municipality, .direction = "down") %>%
  select(-Meta1,-Meta2)

# Tidying the data by putting years into rows, sorting and reordering columns
PersonalIncomeAfterTax <- PersonalIncomeAfterTax %>%
  pivot_longer(
    cols = any_of(ColWithYears),
    names_to = "Year",
    values_to = "AvgDisposableIncome"
  ) %>%
  mutate(
    AvgDisposableIncome = as.numeric(AvgDisposableIncome),
    Year = as.numeric(Year),
    Gender = case_when(
      Gender == "Mænd og kvinder i alt" ~ "Total",
      Gender == "Mænd" ~ "Men",
      Gender == "Kvinder" ~ "Women"
    )
  ) %>%
  filter(!is.na(AvgDisposableIncome))

# Creating separate columns for each income metric and calculating the
# income gap between the two genders
PersonalIncomeAfterTax_Wide <- PersonalIncomeAfterTax %>%
  mutate(Metric = paste("AvgDisposableIncome", Gender, sep = "")) %>%
  pivot_wider(
    id_cols = c("Year", "Municipality"),
    names_from = "Metric",
    values_from = "AvgDisposableIncome"
  ) %>%
  mutate(
    IncomeGapPct = (AvgDisposableIncomeMen - AvgDisposableIncomeWomen) / AvgDisposableIncomeMen
  ) %>%
  mutate(IncomeGapPct = round(100 * IncomeGapPct, 1))

# Adding disposable annual income growth rates
PersonalIncomeAfterTax_Wide <- PersonalIncomeAfterTax_Wide %>%
  arrange(Year, Municipality) %>%
  group_by(Municipality) %>%
  mutate(
    PrevIncomeMen = lag(AvgDisposableIncomeMen, 1),
    PrevIncomeWomen = lag(AvgDisposableIncomeWomen, 1),
    PrevIncomeTotal = lag(AvgDisposableIncomeTotal, 1)
  ) %>%
  ungroup() %>%
  mutate(
    IncomeGrowthMen = (AvgDisposableIncomeMen - PrevIncomeMen) / PrevIncomeMen,
    IncomeGrowthWomen = (AvgDisposableIncomeWomen - PrevIncomeWomen) / PrevIncomeWomen,
    IncomeGrowthTotal = (AvgDisposableIncomeTotal - PrevIncomeTotal) / PrevIncomeTotal
  ) %>%
  mutate(
    IncomeGrowthMen = round(100 * IncomeGrowthMen, 1),
    IncomeGrowthWomen = round(100 * IncomeGrowthWomen, 1),
    IncomeGrowthTotal = round(100 * IncomeGrowthTotal, 1)
  ) %>%
  select(-starts_with("Prev"))


# Creating annual sales data for owned flats ====

"
======================================
In here, we use two different methods:
======================================
1) For data prior to 2004, we calculate the simple average price
in each municipality.
2) For data starting from 2004, we calculate the weighted average price
for each municipality so as to also account for the number of sales.
"

# Preparing annual data for years prior to 2004
OwnFlatPricesPrior <- OwnFlatPrices %>%
  filter(Year < 2004) %>%
  left_join(MappingTable, by = "PostCode") %>%
  group_by(Municipality, Year) %>%
  mutate(AvgSalesPrice = mean(AvgPricePerSquareMeter, na.rm = TRUE)) %>%
  ungroup() %>%
  distinct(Municipality, Year, .keep_all = TRUE) %>%
  select(-AvgPricePerSquareMeter,
         -PostCode,
         -Location,
         -YearQuarter,
         -Quarter)

# Preparing a slimmed-down version of the table containing sales numbers
TempSales <- OwnFlatSales %>%
  select(PostCode, YearQuarter, NumberOfSales)

# Preparing annual data for 2004 and after
# Note: we introduce NA for number of sales wherever we have missing prices
# so as not to make the weighted average price appear lower than it actually is
OwnFlatPricesAfter <- OwnFlatPrices %>%
  filter(Year >= 2004) %>%
  left_join(TempSales, by = c("PostCode", "YearQuarter")) %>%
  left_join(MappingTable, by = "PostCode") %>%
  mutate(
    NumberOfSalesForUse = ifelse(is.na(AvgPricePerSquareMeter), NA, NumberOfSales),
    SumPricePerSquareMeter = AvgPricePerSquareMeter * NumberOfSalesForUse
  ) %>%
  group_by(Municipality, Year) %>%
  mutate(
    TotalSalesPrice = sum(SumPricePerSquareMeter, na.rm = TRUE),
    TotalSales = sum(NumberOfSalesForUse, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  distinct(Municipality, Year, .keep_all = TRUE) %>%
  mutate(AvgSalesPrice = TotalSalesPrice / TotalSales) %>%
  select(
    -AvgPricePerSquareMeter,
    -SumPricePerSquareMeter,
    -PostCode,
    -Location,
    -TotalSalesPrice,
    -NumberOfSales,
    -NumberOfSalesForUse,
    -YearQuarter,
    -Quarter
  )

# Putting the data in a single data frame
OwnFlatAnnualPrices <-
  plyr::rbind.fill(OwnFlatPricesPrior, OwnFlatPricesAfter) %>%
  arrange(Year, Municipality)


# Macroeconomic data from the IMF's World Economic Outlook ====

# Note: the data is pre-filtered for Denmark to cover the period 1980-2028
# WEO for Denmark is updated twice a year: in June and in October
# Source: "https://www.imf.org/en/Publications/WEO/weo-database/2023/October/weo-report?c=128,&s=NGDP_R,NGDP_RPCH,PCPI,PCPIPCH,PCPIE,PCPIEPCH,LP,&sy=1980&ey=2028&ssm=0&scsm=1&scc=1&ssd=1&ssc=1&sic=0&sort=country&ds=.&br=1"

# Importing the data
MacroDataIMF <- read_excel("Input data/WEO_Data_Denmark.xlsx") %>%
  filter(Country == "Denmark")

# Getting column names that contain years
ColsWithYears <-
  grep("^19[8-9][0-9]$|^20[0-4][0-9]$|^2050$",
       names(MacroDataIMF),
       value = TRUE)

# Converting the data to a long format and marking observation type
MacroDataIMF <- MacroDataIMF %>%
  pivot_longer(cols = any_of(ColsWithYears), names_to = "Year") %>%
  mutate(ObservationType = ifelse(Year < `Estimates Start After`,
         "Historical value",
         "Estimation/Prediction"),
         Varname = paste(`Subject Descriptor`, Units, sep = "_")
         )

# Preparing proper column names before conversion back to wide format
MacroDataIMF <- MacroDataIMF %>%
  mutate(
    VarnameForPivot = case_when(
      Varname == "Gross domestic product, current prices_National currency" ~ "GDP",
      Varname == "Inflation, average consumer prices_Index" ~ "AvgInflation",
      Varname == "Inflation, average consumer prices_Percent change" ~ "AvgInflation_PctChange",
      Varname == "Inflation, end of period consumer prices_Index" ~ "AnnualInflation",
      Varname == "Inflation, end of period consumer prices_Percent change" ~ "AnnualInflation_PctChange",
      Varname == "Population_Persons" ~ "Population"
    )
  )

# Converting back to a wide format, this time with indicators in columns
# and years in rows
MacroDataIMF <- MacroDataIMF %>%
  pivot_wider(
    id_cols = c("Year", "ObservationType"),
    names_from = "VarnameForPivot",
    values_from = "value"
  )

# Repairing formats
MacroDataIMF <- MacroDataIMF %>%
  mutate(Year = as.integer(Year))


# Data on interest rate from Denmark's national bank ====
# Source: DST (MPK3)

# Importing data
InterestRate <- read_excel("Input data/MPK3.xlsx", skip = 2)

# Converting the data to long format
ColsWithMonths <- names(InterestRate)[2:length(names(InterestRate))]
names(InterestRate)[1] <- "Indicator"
InterestRate <- InterestRate %>%
  pivot_longer(
    cols = any_of(ColsWithMonths),
    names_to = "YearMonth",
    values_to = "NationalInterestRate"
  ) %>%
  mutate(Year = substr(YearMonth, start = 1, stop = 4),
         Year = as.integer(Year)) %>%
  select(-Indicator, -YearMonth)

# Aggregating on an annual basis (we use the median value)
AnnualInterestRate <- InterestRate %>%
  group_by(Year) %>%
  summarize(MedianInterestRate = median(NationalInterestRate)) %>%
  mutate(ObservationType = "Historical data")

# Calculating the all-time historical median interest rate and adding rows
# for future years that use the all-time median value
HistoricalMedianInterestRate <- median(InterestRate$NationalInterestRate)
MaxFutureYear <- max(MacroDataIMF$Year)
MinFutureYear <- max(AnnualInterestRate$Year) + 1
FutureInflation <- c(MinFutureYear:MaxFutureYear)
FutureInflation <- as.data.frame(FutureInflation)
names(FutureInflation) <- "Year"
FutureInflation$MedianInterestRate <- HistoricalMedianInterestRate
FutureInflation$ObservationType <- "Assumption"
AnnualInterestRate <- rbind(AnnualInterestRate, FutureInflation)


# Exporting the data for further analysis ====

# Exporting each individual dataset
# Note: this will be used to impute for missing values and generate predictions
# for future time periods in the subsequent steps
write_parquet(OwnFlatPrices, "Temp data/OwnFlatPrices.parquet")
write_parquet(OwnFlatSales, "Temp data/OwnFlatSales.parquet")
write_parquet(OwnFlatAnnualPrices, "Temp data/OwnFlatAnnualPrices.parquet")
write_parquet(PersonalIncomeAfterTax,
              "Temp data/PersonalIncomeAfterTax.parquet")
write_parquet(PersonalIncomeAfterTax_Wide,
              "Temp data/PersonalIncomeAfterTax_Wide.parquet")
write_parquet(MacroDataIMF, "Temp data/MacroDataIMF.parquet")
write_parquet(InterestRate, "Temp data/InterestRate.parquet")
write_parquet(AnnualInterestRate, "Temp data/AnnualInterestRate.parquet")

# Printing a notice to the user
print("Note: Data cleaning successfully completed.")
print("The data have been successfully exported to the local folders.")
