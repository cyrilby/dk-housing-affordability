# Data preparation for further analysis (part 1 of 4)

# Author: kirilboyanovbg[at]gmail.com
# Last meaningful update: 21-03-2024

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

# Specifying local storage folder
AnalysisFolder <-
  "C:/Users/Documents/Hsng prices/"
setwd(AnalysisFolder)

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


# Personal disposable income by quarter and municipality ====
# Source: DST (Table: INDKP101)

# Reading file exported from DST
PersonalIncomeAfterTax <-
  read_excel(paste(AnalysisFolder, "Input data/INDKP101.xlsx", sep = ""),
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


# Personal disposable income by income brackets and municipality [WIP as of 24-01-2024] ====
# Source: DST (Table: INDKP106)

"
==============
Kiril's notes:
==============
This would be a useful expansion in the future as it will allow us to compare
the number of m2 that a person from the lowest X income brackets would be able
to buy, relative to a person from the highest income bracket. However, the
calculations may be a bit too complex, so I will be leaving this out in the first
iteration.
"

# Reading file exported from DST
IncomeBracketsAfterTax <-
  read_excel(paste(AnalysisFolder, "Input data/INDKP106 - indkomst.xlsx", sep = ""),
             skip = 2)

# Repairing column names
ColNames <- names(IncomeBracketsAfterTax)
ColWithYears <- ColNames[6:length(ColNames)]
ColNames <-
  append(c("Meta1", "Meta2", "Meta3", "IncomeBracket", "Municipality"),
         ColWithYears)
names(IncomeBracketsAfterTax) <- ColNames

# Repairing metric names: forward filling and removing footnotes
IncomeBracketsAfterTax <- IncomeBracketsAfterTax %>%
  fill(IncomeBracket, Municipality, .direction = "down") %>%
  select(-Meta1,-Meta2, -Meta3)

# Tidying the data by putting years into rows, sorting and reordering columns
IncomeBracketsAfterTax <- IncomeBracketsAfterTax %>%
  pivot_longer(
    cols = any_of(ColWithYears),
    names_to = "Year",
    values_to = "AvgDisposableIncome"
  ) %>%
  mutate(AvgDisposableIncome = as.numeric(AvgDisposableIncome),
         Year = as.numeric(Year)) %>%
  filter(!is.na(AvgDisposableIncome))


# Creating separate columns for each income bracket
IncomeBracketsAfterTax_Wide <- IncomeBracketsAfterTax %>%
  mutate(Metric = paste("AvgDisposableIncome", IncomeBracket, sep = "")) %>%
  pivot_wider(
    id_cols = c("Year", "Municipality"),
    names_from = "IncomeBracket",
    values_from = "AvgDisposableIncome"
  )


# Household income after tax ====
# Source: DST (Table: INDKF132)

# Reading file exported from DST
HouseholdIncomeAfterTax <-
  read_excel(paste(AnalysisFolder, "Input data/INDKF132.xlsx", sep = ""),
             skip = 2)

# Repairing column names
ColNames <- names(HouseholdIncomeAfterTax)
ColWithYears <- ColNames[5:length(ColNames)]
ColNames <-
  append(c("Empty", "IncomeRange", "Metric", "Municipality"),
         ColWithYears)
names(HouseholdIncomeAfterTax) <- ColNames

# Repairing metric names: forward filling and removing footnotes
HouseholdIncomeAfterTax <- HouseholdIncomeAfterTax %>%
  fill(IncomeRange, Metric, .direction = "down") %>%
  filter(is.na(Empty)) %>%
  select(-Empty)

# Tidying the data by putting years into rows, sorting and reordering columns
HouseholdIncomeAfterTax <- HouseholdIncomeAfterTax %>%
  pivot_longer(
    cols = any_of(ColWithYears),
    names_to = "Year",
    values_to = "ValueForMetric"
  ) %>%
  arrange(Year, Municipality, IncomeRange, Metric) %>%
  select(Year, Municipality, IncomeRange, Metric, ValueForMetric) %>%
  mutate(
    Metric = case_when(
      Metric == "Familier i gruppen (Antal)" ~ "Number of households",
      Metric == "Indkomstbeløb (1.000 kr.)" ~ "Income after tax (1,000 DKK)",
      Metric == "Gennemsnit for familier i gruppen (kr.)" ~ "Average income after tax in group"
    )
  ) %>%
  mutate(Year = as.numeric(Year))

# Creating separate columns for each income metric
# Note: different structures needed for BI/modelling
HouseholdIncomeAfterTax_Wide <- HouseholdIncomeAfterTax %>%
  mutate(
    IncomeRange = case_when(
      IncomeRange == "Under 200.000 kr." ~ "Max_199K",
      IncomeRange == "200.000 - 299.999 kr." ~ "Max_299K",
      IncomeRange == "300.000 - 399.999 kr." ~ "Max_399K",
      IncomeRange == "400.000 - 499.999 kr." ~ "Max_499K",
      IncomeRange == "500.000 - 599.999 kr." ~ "Max_599K",
      IncomeRange == "600.000 - 699.999 kr." ~ "Max_699K",
      IncomeRange == "700.000 - 799.000 kr." ~ "Max_799K",
      IncomeRange == "800.000 - 899.000 kr." ~ "Max_899K",
      IncomeRange == "900.000 - 999.000 kr." ~ "Max_999K",
      IncomeRange == "1 million kr. og derover" ~ "Min_1M",
      IncomeRange == "I alt" ~ "Total"
    ),
    Metric = case_when(
      Metric == "Number of households" ~ "N_Households",
      Metric == "Income after tax (1,000 DKK)" ~ "Income_AfTax",
      Metric == "Average income after tax in group" ~ "AvgGroupIncome"
    ),
    Metric = paste(Metric, IncomeRange, sep = "_")
  ) %>%
  pivot_wider(
    id_cols = c("Year", "Municipality"),
    names_from = "Metric",
    values_from = "ValueForMetric"
  )

# Creating columns indicating the % of household in each income bracket
HouseholdIncomeAfterTax_Wide <- HouseholdIncomeAfterTax_Wide %>%
  mutate(
    Pct_Households_Max_199K = 100 * (N_Households_Max_199K / N_Households_Total),
    Pct_Households_Max_299K = 100 * (N_Households_Max_299K / N_Households_Total),
    Pct_Households_Max_399K = 100 * (N_Households_Max_399K / N_Households_Total),
    Pct_Households_Max_499K = 100 * (N_Households_Max_499K / N_Households_Total),
    Pct_Households_Max_599K = 100 * (N_Households_Max_599K / N_Households_Total),
    Pct_Households_Max_699K = 100 * (N_Households_Max_699K / N_Households_Total),
    Pct_Households_Max_799K = 100 * (N_Households_Max_799K / N_Households_Total),
    Pct_Households_Max_899K = 100 * (N_Households_Max_899K / N_Households_Total),
    Pct_Households_Max_999K = 100 * (N_Households_Max_999K / N_Households_Total),
    Pct_Households_Min_1M = 100 * (N_Households_Min_1M / N_Households_Total)
  ) %>%
  mutate_if(is.numeric, ~ ifelse(is.na(.), 0, .))


# Wealth from ownership of real estate ====
# Used as proxy for relative richness
# Source: DST (Table: EJDFOE1)

# Reading file exported from DST
WealthRealEstate <-
  read_excel(paste(AnalysisFolder, "Input data/EJDFOE1.xlsx", sep = ""),
             skip = 2)

# Repairing column names
ColNames <- names(WealthRealEstate)
ColWithYears <- ColNames[5:length(ColNames)]
ColNames <-
  append(c("AssessmentType", "EstateType", "Metric", "Municipality"),
         ColWithYears)
names(WealthRealEstate) <- ColNames

# Repairing metric names: changing case and forward filling
WealthRealEstate <- WealthRealEstate %>%
  mutate(EstateType = ifelse(
    EstateType %in% SpellingToFix,
    str_to_sentence(EstateType),
    EstateType
  )) %>%
  fill(AssessmentType, EstateType, Metric, .direction = "down") %>%
  filter(!is.na(Municipality))

# Tidying the data by putting years into rows, sorting and reordering columns
# Note: includes translation of values to English and standardizing DKK units
WealthRealEstate <- WealthRealEstate %>%
  pivot_longer(
    cols = any_of(ColWithYears),
    names_to = "Year",
    values_to = "ValueForMetric"
  ) %>%
  arrange(Year, Municipality, EstateType, Metric) %>%
  select(Year, Municipality,  EstateType, Metric, ValueForMetric) %>%
  mutate(
    Year = as.numeric(Year),
    EstateType = case_when(
      EstateType == "A. Enfamiliehuse" ~ "A. Family houses",
      EstateType == "B. Ejerlejligheder" ~ "B. Fully-owned flats",
      EstateType == "C. Flerfamiliehuse" ~ "C. Multi-family houses",
      EstateType == "D. Andelsboliger" ~ "D. Partly-owned flats",
      EstateType == "E. Beboelsesejendomme forbundet med erhverv" ~ "E. Mixed living and business",
      EstateType == "F. Andre beboelsesejendomme" ~ "F. Other living",
      EstateType == "G. Bebyggede landbrug" ~ "G. Agricultural buildings",
      EstateType == "H. Sommerhuse mm." ~ "H. Holiday homes",
      EstateType == "I. Grunde, landbrugsarealer og naturområder" ~ "I. Land",
      EstateType == "J. Erhvervsejendomme" ~ "J. Business properties",
      EstateType == "K. Anden fast ejendom" ~ "K. Other real estate",
      EstateType == "Fast ejendom i alt" ~ "Total real estate"
    ),
    Metric = case_when(
      Metric == "Ejendomme (Antal)" ~ "Number of properties",
      Metric == "Gennemsnit (Kr.)" ~ "Average value (DKK)",
      Metric == "Total (mio. kr.)" ~ "Total value (DKK)"
    )
  ) %>%
  mutate(
    ValueForMetric = ifelse(
      Metric == "Total value (DKK)",
      ValueForMetric * 1000000,
      ValueForMetric
    )
  )

# Creating separate columns for each fortune metric
# Note: different structures needed for BI/modelling
WealthRealEstate_Wide <- WealthRealEstate %>%
  mutate(
    EstateType = case_when(
      EstateType == "A. Family houses" ~ "FamHouses",
      EstateType == "B. Fully-owned flats" ~ "OwnFlats",
      EstateType == "C. Multi-family houses" ~ "MultiFamHouses",
      EstateType == "D. Partly-owned flats" ~ "PartOwnFlats",
      EstateType == "E. Mixed living and business" ~ "Mixed",
      EstateType == "F. Other living" ~ "OtherLiving",
      EstateType == "G. Agricultural buildings" ~ "AgroBuild",
      EstateType == "I. Land" ~ "Land",
      EstateType == "J. Business properties" ~ "Business",
      EstateType == "K. Other real estate" ~ "Others",
      EstateType == "Total real estate" ~ "Total"
    ),
    Metric = case_when(
      Metric == "Number of properties" ~ "N",
      Metric == "Average value (DKK)" ~ "AvgVal",
      Metric == "Total value (DKK)" ~ "TotalVal"
    ),
    Metric = paste(Metric, EstateType, sep = "_")
  ) %>%
  pivot_wider(
    id_cols = c("Year", "Municipality"),
    names_from = "Metric",
    values_from = "ValueForMetric"
  )


# National economy ====
# Source: DST (Table: NAN1)

# Reading file exported from DST
NationalEconomy <-
  read_excel(paste(AnalysisFolder, "Input data/NAN1.xlsx", sep = ""), skip = 2)

# Repairing column names
ColNames <- names(NationalEconomy)
ColWithYears <- ColNames[3:length(ColNames)]
ColNames <- append(c("PriceType", "Metric"), ColWithYears)
names(NationalEconomy) <- ColNames

# Tidying the data by putting years into rows, sorting and reordering columns
NationalEconomy <- NationalEconomy %>%
  pivot_longer(
    cols = any_of(ColWithYears),
    names_to = "Year",
    values_to = "ValueForMetric"
  ) %>%
  select(Year, Metric, ValueForMetric) %>%
  arrange(Year) %>%
  mutate(Year = as.numeric(Year)) %>%
  filter(!is.na(Metric))

# Transcoding values to English
NationalEconomy <- NationalEconomy %>%
  mutate(
    Metric = case_when(
      Metric == "B.1*g Bruttonationalprodukt, BNP" ~ "Total GDP",
      Metric == "P.31 Husholdningernes forbrugsudgifter" ~ "Household expenditure",
      Metric == "Turistudgifter" ~ "Spending on tourism",
      Metric == "Turistindtægter" ~ "Income from tourism",
      Metric == "P.7 Import af varer og tjenester" ~ "Imports of goods and services",
      Metric == "Tjenester i alt" ~ "Total services",
      Metric == "P.5g Bruttoinvesteringer" ~ "Total investment",
      Metric == "Samlet antal beskæftigede (1000 personer)" ~ "Total employed (1,000 people)"
    )
  )

# Create a wider format with separate columns for each metric
NationalEconomy_Wide <- NationalEconomy %>%
  mutate(
    Metric = case_when(
      Metric == "Total GDP" ~ "TotalGDP",
      Metric == "Household expenditure" ~ "HouseholdExpenditure",
      Metric == "Spending on tourism" ~ "TourismSpending",
      Metric == "Income from tourism" ~ "TourismIncome",
      Metric == "Imports of goods and services" ~ "ImportsGoodsServices",
      Metric == "Total services" ~ "TotalServices",
      Metric == "Total investment" ~ "TotalInvestment",
      Metric == "Total employed (1,000 people)" ~ "TotalEmployed"
    )
  ) %>%
  pivot_wider(
    id_cols = c("Year"),
    names_from = "Metric",
    values_from = "ValueForMetric"
  ) %>%
  mutate(TotalEmployed = 1000 * TotalEmployed)

# Calculating growth rates
VarsForGrowthCalc <-
  names(NationalEconomy_Wide)[2:length(names(NationalEconomy_Wide))]
for (var in VarsForGrowthCalc) {
  # Adding 1-year lags
  NationalEconomy_Wide[[paste(var, "L1", sep = "_")]] <-
    lag(NationalEconomy_Wide[[var]], n = 1)
  # Calculating growth in %
  NationalEconomy_Wide[[paste(var, "Growth", sep = "_")]] <-
    100 * ((NationalEconomy_Wide[[var]] - NationalEconomy_Wide[[paste(var, "L1", sep = "_")]]) /
             NationalEconomy_Wide[[paste(var, "L1", sep = "_")]])
  # Deleting 1-year lags
  NationalEconomy_Wide[[paste(var, "L1", sep = "_")]] <- NULL
}


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
      Varname == "Gross domestic product, constant prices_National currency" ~ "GDP",
      Varname == "Gross domestic product, constant prices_Percent change" ~ "GDP_PctChange",
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
write_parquet(HouseholdIncomeAfterTax_Wide,
              "Temp data/HouseholdIncomeAfterTax_Wide.parquet")
write_parquet(HouseholdIncomeAfterTax,
              "Temp data/HouseholdIncomeAfterTax.parquet")
write_parquet(WealthRealEstate, "Temp data/WealthRealEstate.parquet")
write_parquet(WealthRealEstate_Wide,
              "Temp data/WealthRealEstate_Wide.parquet")
write_parquet(NationalEconomy, "Temp data/NationalEconomy.parquet")
write_parquet(MacroDataIMF, "Temp data/MacroDataIMF.parquet")
write_parquet(InterestRate, "Temp data/InterestRate.parquet")
write_parquet(AnnualInterestRate, "Temp data/AnnualInterestRate.parquet")

# Printing a notice to the user
print("Note: Data cleaning successfully completed.")
print("The data have been successfully exported to the local folders.")
