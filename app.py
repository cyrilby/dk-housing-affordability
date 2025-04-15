"""
======================
Streamlit app backbone
======================

Author: kirilboyanovbg[at]gmail.com
Last meaningful update: 15-04-2025
"""

# %% Setting things up

# Importing relevant packages
import pandas as pd
import numpy as np
import datetime as dt
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go

# Getting current, previous and next year
current_year = dt.datetime.now().year
prev_year = current_year - 1
next_year = current_year + 1


# %% Importing data for use in the app

# Importing data that was already pre-processed in a separate R script
sales_data = pd.read_parquet("Output data/FinalSalesAndIncome.parquet")
income_fit_metrics = pd.read_parquet("Output data/IncomeModelFitMetrics.parquet")
price_fit_metrics = pd.read_parquet("Output data/SalesModelFitMetrics.parquet")
price_imp_metrics = pd.read_parquet(
    "Output data/SalesPriceImputationFitMetrics.parquet"
)
indexed_development = pd.read_parquet("Output data/IndexedDevelopment.parquet")


# Getting macroeconomic data the assumptions are based on
macro_data = pd.read_parquet("Temp data/MacroDataIMF.parquet")
interest_rate = pd.read_parquet("Temp data/AnnualInterestRate.parquet")
interest_rate = interest_rate[["Year", "MedianInterestRate"]]
macro_data = pd.merge(macro_data, interest_rate, how="left", on="Year")
med_int = interest_rate["MedianInterestRate"].iloc[-1]

# Getting the latest year with actual sales data
last_historical_year = sales_data[sales_data["PriceType"] != "Predicted price"][
    "Year"
].max()

# Getting all unique historical years
# (used to define the number of years displayed in the slicer)
unique_years = (
    sales_data[sales_data["PriceType"] != "Predicted price"]["Year"]
    .unique()
    .astype(int)
    .tolist()
)
n_years = len(unique_years)
n_possible_years = np.arange(1, n_years + 1)
n_years_to_include = np.arange(2, n_years)

# Preparing a list of years to use as filter in the app
unique_years.sort(reverse=True)

# Getting all unique future years
future_years = (
    sales_data[sales_data["PriceType"] == "Predicted price"]["Year"]
    .unique()
    .astype(int)
    .tolist()
)
n_future_years = len(future_years)

# Creating a dictionary that maps years according to their recency
annual_recency = dict(zip(unique_years, n_possible_years))

# Mapping annual recency in all relevant datasets
sales_data["Recency"] = sales_data["Year"].map(annual_recency)
sales_data["Recency"] = sales_data["Recency"].fillna(0)
indexed_development["Recency"] = indexed_development["Year"].map(annual_recency)
indexed_development["Recency"] = indexed_development["Recency"].fillna(0)

# Defining a custom set of price type combinations to show in slicer
price_type_combinations = [
    "Historical data incl. estimates",
    "Historical data excl. estimates",
    "Historical data and predictions",
]

# Defining more user-friendly names for the accuracy metrics tables
new_col_names = {
    "ModelR2_Total": "Total income, R² (%)",
    "ModelR2_Men": "Male income, R² (%)",
    "ModelR2_Women": "Female income, R² (%)",
    "ModelMAPE_Total": "Total income, MAPE (%)",
    "ModelMAPE_Men": "Male income, MAPE (%)",
    "ModelMAPE_Women": "Female income, MAPE (%)",
    "PctAccuracy_Total": "Total income, Accuracy (%)",
    "PctAccuracy_Men": "Male income, Accuracy (%)",
    "PctAccuracy_Women": "Female income, Accuracy (%)",
    "ModelR2_SalesPrice": "Sales price, R² (%)",
    "ModelMAPE_SalesPrice": "Sales price, MAPE (%)",
    "PctAccuracy_SalesPrice": "Sales price, Accuracy (%)",
    "VariableName": "Variable name",
    "ModelMSE": "Mean squared error (MSE)",
    "MeanValue": "Mean value",
    "ModelRMSE": "RMSE",
    "ModelNormalizedRMSE": "Normalized RMSE (%)",
    "PctAccuracy": "Accuracy (%)",
}

# Renaming columns in accordance with the above dictionary
income_fit_metrics = income_fit_metrics.rename(columns=new_col_names)
price_fit_metrics = price_fit_metrics.rename(columns=new_col_names)
price_imp_metrics = price_imp_metrics.rename(columns=new_col_names)

# Transposing the imputations table for better user-friendliness
# Note: we only keep fit metrics for "AvgSalesPrice" to make it less confusing
price_imp_metrics = price_imp_metrics[
    price_imp_metrics["Variable name"] == "AvgSalesPrice"
]
price_imp_metrics = price_imp_metrics.transpose()
price_imp_metrics = price_imp_metrics.drop(price_imp_metrics.index[0])
price_imp_metrics.columns = ["Average sales price"]

# Getting the last year with historical data
last_hist_year = unique_years[0]


# %% Preparing some basic things for the app

# Setting up the web page title and icon of the app
st.set_page_config(page_title="DK housing affordability", page_icon="🏠")

# Adding title to the app's sidebar
st.sidebar.title("DK housing affordability")

# Adding a list of pages to the sidebar
# NB: REMEMBER TO INCLUDE ALL PAGES IN THE "OPTIONS" LIST
options = st.sidebar.radio(
    "Pages",
    options=[
        "Welcome",
        "Pricing overview",
        "Affordability overview",
        "Pricing by municipality",
        "Affordability by municipality",
        "Affordability by gender",
        "Indexed developments",
        "Historical changes",
        "Info on data sources",
        "Info on modelling",
        "Legal disclaimer",
    ],
)


# Setting up sidebar filter for metric to show
def filter_metric(list_of_metrics):
    selected_metric = st.sidebar.selectbox("Selected metric", list_of_metrics)
    # Converting user input to pandas-like input
    if selected_metric == "Actual price":
        metric_for_use = "AvgSalesPrice"
    elif selected_metric == "Price index":
        metric_for_use = "AvgSalesPriceIdx"
    elif selected_metric == "Buyable m² with annual income":
        metric_for_use = "M2AffordedTotal"
    elif selected_metric == "Years of income to buy 50 m²":
        metric_for_use = "YearsoBuy50M2Total"
    else:
        metric_for_use = None
    return metric_for_use


# Setting up sidebar filter for price type
def filter_price_type(list_of_price_types):
    selected_metric = st.sidebar.multiselect(
        "Selected price type(s)", list_of_price_types, default=list_of_price_types
    )
    return selected_metric


# Setting up sidebar filter for number of years to show
def filter_by_year(list_of_years):
    selected_years = st.sidebar.select_slider(
        "Selected number of past years (up to)",
        list_of_years.values(),
        value=np.max(list(list_of_years.values())),
    )
    return selected_years


# Setting up sidebar filters for baseline and reference years
def filter_by_year_base(hist_years, future_years):
    all_years = hist_years + future_years
    all_years.sort()
    selected_years = st.sidebar.selectbox(
        "Selected baseline year",
        all_years,
        index=all_years.index(np.min(hist_years)),
    )
    return selected_years


def filter_by_year_ref(hist_years, future_years):
    all_years = hist_years + future_years
    all_years.sort()
    selected_years = st.sidebar.selectbox(
        "Selected reference year",
        all_years,
        index=all_years.index(np.max(hist_years)),
    )
    return selected_years


# Setting up sidebar filter for number of municipalities to show
def filter_by_n_mncp(list_of_municipalities, default_number):
    possible_numbers = np.arange(1, len(list_of_municipalities) + 1).tolist()
    selected_number = st.sidebar.selectbox(
        "Number of top municipalities to show",
        possible_numbers,
        index=possible_numbers.index(default_number),
    )
    return selected_number


# Setting up sidebar filter for a specific year to show on page
# where no historic development is shown
def filter_by_specific_year(possible_years):
    selected_year = st.sidebar.selectbox(
        "Year", possible_years, index=possible_years.index(last_historical_year)
    )
    return selected_year


# Setting up sidebar filter for multiple locations at the same time (municipalities)
def filter_by_location(dataset, location_var, default_val):
    possible_entries = dataset[location_var].unique()
    selected_entries = st.sidebar.multiselect(
        "Municipality",
        possible_entries,
        default=default_val,
    )
    # If no option is selected, select all by default
    if not selected_entries:
        st.warning(
            """Warning: No selected municipality.
            Showing the national average instead."""
        )
        selected_entries = ["National average"]
    return selected_entries


# Setting up sidebar filter for a single location at a same time (municipality)
def filter_by_single_location(dataset, location_var, default_val):
    possible_entries = dataset[location_var].unique().tolist()
    selected_location = st.sidebar.selectbox(
        "Municipality", possible_entries, index=possible_entries.index(default_val)
    )
    return selected_location


# Setting up a sidebar filter to control the kind of price data shown
def filter_price_type_new(possible_entries, default_val):
    selected_combination = st.sidebar.selectbox(
        "Selected price type(s)",
        possible_entries,
        index=possible_entries.index(default_val),
    )
    if selected_combination == "Historical data incl. estimates":
        allowed_types = ["Actual price", "Estimated price"]
    elif selected_combination == "Historical data excl. estimates":
        allowed_types = ["Actual price"]
    elif selected_combination == "Historical data and predictions":
        allowed_types = ["Actual price", "Estimated price", "Predicted price"]
    return allowed_types


# Setting up a sidebar filter to control the kind of fit metrics shown
def filter_fit_metrics(default_val):
    possible_entries = ["Accuracy (%) only", "R² only", "MAPE/RMSE only", "All"]
    selected_metrics = st.sidebar.selectbox(
        "Show the following metrics",
        possible_entries,
        index=possible_entries.index(default_val),
    )
    return selected_metrics


# Setting up a function that adds the MindGraph logo
def add_logo():
    """
    Adds the MindGraph logo to the upper left corner of the page.
    """
    st.logo(
        "https://mindgraph.dk/logo.svg",
        size="large",
        link="https://mindgraph.dk",
        icon_image="https://mindgraph.dk/favicon.svg",
    )


# %% Page: Welcome to the app


# Informs the user of the app's purpose and the selected metric for N of employees
def show_homepage():
    st.header("Welcome to the DK housing affordability app!")
    add_logo()
    st.markdown(
        """
        This app is designed to give you an insight into what **sales prices** of flats
        in different Danish municipalities look like and **how affordable** buying a flat is. All data on prices, GDP
        and income shown in the app is in *nominal prices*.
        """
    )
    st.markdown(
        "**Please scroll down** to learn more about how this app can help you and how to use it."
    )
    # Note: image sourced from https://pixabay.com/photos/canal-copenhagen-christianshavn-2395818/
    st.image("Resources/app_image.jpg")

    # Displaying more info on how the app can help the user
    st.subheader("How this app can help you", divider="rainbow")
    st.markdown(
        """This app focuses on both the sales price of flats and their affordability
        (measured in terms of its relation to personal income). The focus in here is on
        the so-called "owned flats" (called *ejerbolig* in Danish).
        """
    )
    st.markdown(
        "**Using this app, you will be able to find answers to questions such as:**"
    )
    st.markdown(
        f"""
        - How have prices evolved in the past both in general and for each municipality?
        - How has housing affordability changed, i.e. comparing pricing to personal income?
        - Which are the most and least expensive municipalities in e.g. {last_hist_year}?
        - How will prices and affordability evolve in the next few years based on
        historical trends and future projections for macroeconomic development?
        """
    )
    st.markdown(
        f"""The app contains **historical housing prices** and income statistics
        spanning across **{n_years} years** as well as **predictions** for future
        pricing and affordability covering the next **{n_future_years} years**.
        """
    )

    # Displaying more info on how to use the app
    st.subheader("How to use this app", divider="rainbow")
    st.markdown("This app consists of the following two panes:")
    st.markdown(
        """
        - **The sidebar**: allows you to navigate between the different pages included in
        the app as well as to apply different filters on the data, such as choosing how
        many years/which specific year to show on a chart or choosing between different
        municipalities to display.
        - **The main panel**: contains various charts, tables and text descriptions.
        """
    )
    st.markdown(
        "To **switch between different pages**, please click on the page title:"
    )
    st.image("Resources/pages_examples.PNG")
    st.markdown("You will then be redirected to the desired page.")

    # Displaying more info on how the user can filter the data
    st.subheader("How to apply filters to the data", divider="rainbow")
    st.markdown(
        """To **apply a filter to the data**, please click on the filter
        you wish to apply and select the desired value(s). Please note that some filters
        support *choosing only one value*, for instance the filter that lets you decide whether
        to only show historical data or whether to also include estimated and predicted prices:
        """
    )
    st.image("Resources/filter_price_types.PNG")
    st.markdown(
        """Likewise, other filters let you *choose several different values* at
        the same time, for instance the filter that decides which municipalities are shown
        on the page:
        """
    )
    st.image("Resources/filter_municipalities.PNG")
    st.markdown(
        """**Please note** that if you filter the data too much or remove all pre-made
        selections, there might not be enough data left to display on the charts and the
        app may revert to selecting something for you. Should that be the case, a
        **warning message** will be displayed such as the one below:
        """
    )
    st.image("Resources/selection_warning.PNG")
    st.markdown(
        """To get rid of the warning, please revise your selection
                or refresh the web page to start over.
                """
    )
    st.divider()
    st.markdown("*Front page image source: www.pixabay.com*")


# %% Page: Housing prices by municipality and year


def page_avg_by_mncp(df):
    st.header("Housing prices by municipality and year")
    add_logo()

    # Detecting and confirming slicer selections
    n_years = filter_by_year(annual_recency)
    price_types = filter_price_type_new(
        price_type_combinations, "Historical data incl. estimates"
    )
    metric_for_use = filter_metric(["Actual price", "Price index"])
    selected_locations = filter_by_location(
        df, "Municipality", ["København", "Aarhus", "Odense", "Aalborg"]
    )
    st.markdown(
        f"""On this page, you can see the **average price development** during the 
        last {n_years} years. You can use the filters in the sidebar to
        adjust the number of years shown on the chart as well as which
        municipalities you'd like to see displayed. If you also wish to **display 
        predictions** for the next few years, please enable this option from the 
        *Selected price type(s)* filter in the sidebar."""
    )

    # Filtering the data
    data_to_display = df[df["Recency"] <= n_years].copy()
    data_to_display = data_to_display[
        data_to_display["Municipality"].isin(selected_locations)
    ]
    data_to_display = data_to_display[
        data_to_display["PriceType"].isin(price_types)
    ].copy()

    # Sorting and cleaning up
    data_to_display.sort_values("Year", ascending=False, inplace=True)
    data_to_display = data_to_display[
        [
            "Year",
            "Municipality",
            metric_for_use,
        ]
    ].copy()
    data_to_display.reset_index(inplace=True, drop=True)

    # Rounding off prices (0 decimals) and indices (2 decimals)
    if metric_for_use == "AvgSalesPrice":
        data_to_display[metric_for_use] = np.round(data_to_display[metric_for_use], 0)
        metric_for_use_txt = "Average price per m²"
    else:
        data_to_display[metric_for_use] = np.round(data_to_display[metric_for_use], 2)
        metric_for_use_txt = "Average price per m² (indexed)"

    # Identifying the selected municipalities
    unique_mncp = data_to_display["Municipality"].unique()

    # Checking whether multiple municipalities are selected
    if len(unique_mncp) > 1:
        color_var_for_chart = "Municipality"
        chart_title = metric_for_use_txt + " by municipality and year"
    else:
        color_var_for_chart = None
        chart_title = metric_for_use_txt + f" in {unique_mncp[0]} over time"

    # Plotting the data on a chart
    fig = px.line(
        data_to_display,
        x="Year",
        y=metric_for_use,
        color=color_var_for_chart,
        labels={
            "Year": "Year",
            metric_for_use: metric_for_use_txt,
        },
    )
    fig.update_layout({"title": chart_title})
    fig.update_traces(textposition="top center")
    st.plotly_chart(fig)

    # Displaying more details about how to use the chart
    st.markdown("**Please note that:**")
    st.write(
        """
        1) By default, the chart shows actual sales prices per m² but you can also
        switch to showing indexed prices (first year with available data for the
        respective municipality being equal to 100) using the 'Metric to show'
        filter to get a better idea of the percentage change in housing prices
        across time.
        """
    )
    st.write(
        """
        2) Prices shown for each municipality are based on an annual weighted
        average, calculated based on sales in different post code areas. Some
        rounding off errors may persist.
        """
    )
    st.markdown(
        """
        3) We don't necessarily have data for all municipalities for all yeas,
        which is why some of the prices shown on the chart may be estimates rather
        than actual prices. Please use the *Selected price type(s)* filter in the 
        sidebar if you only wish to look at actual sales prices.
        """
    )
    st.write(
        """
        4) If choosing to show price indices rather than actual prices, then
        estimated prices will be included in the calculation of the index.
        This is done to ensure that the indices are calculated with the same year
        (1992) as the base for all municipalities regardless of data availability.
        """
    )


# %% Page: Housing affordability by municipality and year


def page_afford_by_mncp(df):
    st.header("Affordability by municipality and year")
    add_logo()

    # Detecting and confirming slicer selections
    n_years = filter_by_year(annual_recency)
    metric_for_use = filter_metric(
        ["Buyable m² with annual income", "Years of income to buy 50 m²"]
    )
    price_types = filter_price_type_new(
        price_type_combinations, "Historical data incl. estimates"
    )
    selected_locations = filter_by_location(
        df, "Municipality", ["København", "Aarhus", "Odense", "Aalborg"]
    )
    st.write(
        f"""On this page, you can see how housing affordability has evolved during
        the last {n_years} years. **Two metrics of affordablity** are presented: the
        number of m² that the average person can buy with their annual disposable
        income and the number of years of income it would take the average person
        to buy a 50 m² flat. You can **switch between** these two metrics as
        well as adjust the number of years or the municipalities shown on the chart
        by using the filters in the sidebar. From there, you can also choose to
        **display predictions** for the next few years."""
    )

    # Filtering the data
    data_to_display = df[df["Recency"] <= n_years].copy()
    data_to_display = data_to_display[
        data_to_display["Municipality"].isin(selected_locations)
    ]
    data_to_display = data_to_display[
        data_to_display["PriceType"].isin(price_types)
    ].copy()

    # Sorting and cleaning up
    data_to_display.sort_values("Year", ascending=False, inplace=True)
    data_to_display = data_to_display[
        ["Year", "Municipality", "M2AffordedTotal", "YearsoBuy50M2Total"]
    ].copy()
    data_to_display.reset_index(inplace=True, drop=True)

    # Rounding off to 2 decimals
    data_to_display[metric_for_use] = np.round(data_to_display[metric_for_use], 2)

    # Adjusting names used for the chart
    if metric_for_use == "M2AffordedTotal":
        metric_for_use_txt = "m² buyable with annual disposable income"
        chart_title = "Number of m² that can be bought with annual disposable income"
    else:
        metric_for_use_txt = "Years of annual income needed to buy 50 m²"
        chart_title = "Number of years of disposable income needed to buy 50 m²"

    # Identifying the selected municipalities
    unique_mncp = data_to_display["Municipality"].unique()

    # Checking whether multiple municipalities are selected
    if len(unique_mncp) > 1:
        color_var_for_chart = "Municipality"
    else:
        color_var_for_chart = None
        chart_title = chart_title + f" in {unique_mncp[0]}"

    # Plotting the data on a chart
    fig = px.line(
        data_to_display,
        x="Year",
        y=metric_for_use,
        color=color_var_for_chart,
        labels={
            "Year": "Year",
            metric_for_use: metric_for_use_txt,
        },
    )
    fig.update_layout({"title": chart_title})
    fig.update_traces(textposition="top center")
    st.plotly_chart(fig)

    # Displaying more details about how to use the chart
    st.markdown("**Please note that:**")
    st.write(
        """
        1) By default, the chart shows the number of m² that can be bought with
        the corresponding annual disposable income in the respective municipality.
        Alternatively, you can choose to see how many years of annual disposable
        income will be needed to buy 50 m² through the 'Metric to show' filter
        (not inclusive of the effects of inflation and interest rates).
        """
    )
    st.write(
        """
        2) Prices for each municipality are based on an annual weighted
        average, calculated based on sales in different post code areas. Some
        rounding off errors may persist.
        """
    )
    st.write(
        """
        3) We don't necessarily have data for all municipalities for all yeas,
        which is why some of the figures shown on the chart may be based on
        estimates rather than actual prices. Please use the 'Price type' filter in
        the sidebar if you only wish to look at estimates based on actual
        sales prices.
        """
    )


# %% Page: Housing affordability by municipality, gender and year


def page_afford_by_mncp_gen(df):
    st.header("Affordability by municipality, gender and year")
    add_logo()

    # Detecting and confirming slicer selections
    n_years = filter_by_year(annual_recency)
    metric_for_use = filter_metric(
        ["Buyable m² with annual income", "Years of income to buy 50 m²"]
    )
    price_types = filter_price_type_new(
        price_type_combinations, "Historical data incl. estimates"
    )
    selected_loc = filter_by_single_location(df, "Municipality", "København")
    st.write(
        f"""This page shows the development in housing affordability in the
        last {n_years} years split by gender. The difference in average
        disposable income between men and women will be reflected in housing
        being generally more afforable for men than for women. Please use the
        filters in the sidebar to adjust what data is shown on the chart,
        including whether to **display predictions** for the next few years."""
    )

    # Filtering the data
    data_to_display = df[df["Recency"] <= n_years].copy()
    data_to_display = data_to_display[data_to_display["Municipality"] == selected_loc]
    data_to_display = data_to_display[
        data_to_display["PriceType"].isin(price_types)
    ].copy()

    # Sorting and cleaning up
    data_to_display.sort_values("Year", ascending=False, inplace=True)
    data_to_display = data_to_display[
        [
            "Year",
            "Municipality",
            "M2AffordedMen",
            "M2AffordedWomen",
            "YearsoBuy50M2Men",
            "YearsoBuy50M2Women",
        ]
    ].copy()
    data_to_display.reset_index(inplace=True, drop=True)

    # Rounding all relevant metrics off to 2 decimals
    for metric in [
        "M2AffordedMen",
        "M2AffordedWomen",
        "YearsoBuy50M2Men",
        "YearsoBuy50M2Women",
    ]:
        data_to_display[metric] = np.round(data_to_display[metric], 2)

    # Getting the name of the municipality selected by the user
    selected_mncp = data_to_display["Municipality"].iloc[0]

    # Adjusting names used for the chart
    if metric_for_use == "M2AffordedTotal":
        metric_for_use1 = "M2AffordedMen"
        metric_for_use2 = "M2AffordedWomen"
        metric_for_use_txt = "m² buyable with annual disposable income"
        chart_title = f"Number of m² that can be bought in {selected_mncp} with annual disposable income split by gender"
    else:
        metric_for_use1 = "YearsoBuy50M2Men"
        metric_for_use2 = "YearsoBuy50M2Women"
        metric_for_use_txt = "Years of annual income needed to buy 50 m²"
        chart_title = f"Number of years of disposable income needed to buy 50 m² in {selected_mncp} split by gender"

    # Create a trace for the first variable
    trace1 = go.Scatter(
        x=data_to_display["Year"],
        y=data_to_display[metric_for_use1],
        mode="lines",
        name="Men",
    )

    # Create a trace for the second variable
    trace2 = go.Scatter(
        x=data_to_display["Year"],
        y=data_to_display[metric_for_use2],
        mode="lines",
        name="Women",
    )

    # Create a layout
    layout = go.Layout(
        title=chart_title,
        xaxis=dict(title="Year"),
        yaxis=dict(title=metric_for_use_txt),
    )

    # Create a figure and add the traces
    fig = go.Figure(data=[trace1, trace2], layout=layout)
    fig.update_traces(textposition="top center")
    st.plotly_chart(fig)

    # Displaying more details about how to use the chart
    st.markdown("**Please note that:**")
    st.write(
        """
        1) By default, the chart shows the number of m² that can be bought with
        the corresponding annual disposable income in the respective municipality.
        Alternatively, you can choose to see how many years of annual disposable
        income will be needed to buy 50 m² through the 'Metric to show' filter
        (not inclusive of the effects of inflation and interest rates).
        """
    )
    st.write(
        """
        2) Prices for each municipality are based on an annual weighted
        average, calculated based on sales in different post code areas. Some
        rounding off errors may persist.
        """
    )
    st.write(
        """
        3) We don't necessarily have data for all municipalities for all yeas,
        which is why some of the figures shown on the chart may be based on
        estimates rather than actual prices. Please use the 'Price type' filter in
        the sidebar if you only wish to look at estimates based on actual
        sales prices.
        """
    )
    st.write(
        """
        4) Income as split by gender does not account for potential differences in
        terms of employment status, working hours or type of job held by men and
        women. The income levels used in the affordability calculations are annual 
        averages for both genders.
        """
    )


# %% Page: Indexed developments


def page_indexed_dev(df):
    st.header("Indexed developments in pricing and income")
    add_logo()

    # Detecting and confirming slicer selections
    n_years = filter_by_year(annual_recency)
    price_types = filter_price_type_new(
        price_type_combinations, "Historical data incl. estimates"
    )
    selected_loc = filter_by_single_location(df, "Municipality", "København")
    st.write(
        f"""This page shows the indexed developments in average sales price,
        local disposable income and national GDP during the last {n_years} years.
        As such, it allows for comparisons between how much the price of housing
        has increased relative to the increase in local disposable income and
        relative to the growth of the national economy. Please use the
        filters in the sidebar to adjust what data is shown on the chart,
        including whether to **display predictions** for the next few years."""
    )

    # Filtering the data
    data_to_display = df[df["Recency"] <= n_years].copy()
    data_to_display = data_to_display[data_to_display["Municipality"] == selected_loc]
    data_to_display = data_to_display[
        data_to_display["PriceType"].isin(price_types)
    ].copy()

    # Sorting and cleaning up
    data_to_display.sort_values("Year", ascending=False, inplace=True)
    data_to_display.reset_index(inplace=True, drop=True)

    # Rounding all relevant metrics off to 2 decimals
    for metric in [
        "AvgSalesPriceIdx",
        "AvgDispIncomeIdx",
        "GDPIdx",
    ]:
        data_to_display[metric] = np.round(data_to_display[metric], 2)

    # Create a trace for the first variable
    trace1 = go.Scatter(
        x=data_to_display["Year"],
        y=data_to_display["AvgSalesPriceIdx"],
        mode="lines",
        name="Average sales price",
    )

    # Create a trace for the second variable
    trace2 = go.Scatter(
        x=data_to_display["Year"],
        y=data_to_display["AvgDispIncomeIdx"],
        mode="lines",
        name="Avg disposable income",
    )

    # Create a trace for the second variable
    trace3 = go.Scatter(
        x=data_to_display["Year"],
        y=data_to_display["GDPIdx"],
        mode="lines",
        name="National GDP",
    )

    # Create a layout
    layout = go.Layout(
        title=f"Indexed sales price and local disposable income in {selected_loc} vs. national GDP over time",
        xaxis=dict(title="Year"),
        yaxis=dict(title="Indexed value of indicators"),
    )

    # Create a figure and add the traces
    fig = go.Figure(data=[trace1, trace2, trace3], layout=layout)
    fig.update_traces(textposition="top center")
    st.plotly_chart(fig)

    # Displaying more details about how to use the chart
    st.markdown("**Please note that:**")
    st.write(
        """
        1) The values presented are indexed based on their 1992 values.
        This also includes estimated sales prices for some municipalities
        in order to show a complete historical record. Predictions can also
        be included by selecting the relevant price type from the filter in
        the app's sidebar.
        """
    )


# %% Page: Historical changes across municipalities"


def page_hist_changes(df):
    st.header("Historical changes across municipalities")
    add_logo()

    # For showing side-by-side price changes, we need prices
    # including estimates to ensure we always have data to show
    local_price_combinations = [
        "Historical data incl. estimates",
        "Historical data and predictions",
    ]

    # Detecting and confirming slicer selections
    price_types = filter_price_type_new(
        local_price_combinations, "Historical data incl. estimates"
    )
    if "Predicted price" in price_types:
        ref_year = filter_by_year_ref(unique_years, future_years)
        base_year = filter_by_year_base(unique_years, future_years)
    else:
        ref_year = filter_by_year_ref(unique_years, [])
        base_year = filter_by_year_base(unique_years, [])
    relevant_years = [base_year, ref_year]
    metric_for_use = filter_metric(
        [
            "Actual price",
            "Buyable m² with annual income",
            "Years of income to buy 50 m²",
        ]
    )
    st.write(
        f"""This page summarizes the changes in housing prices/housing
        affordability across municipalities between {base_year}-{ref_year}.
        Please use the filters in the sidebar to adjust what data is shown in the
        table, including whether to **take predictions into account** when
        calculating the changes."""
    )

    # Filtering the data
    data_to_display = df[df["Year"].isin(relevant_years)].copy()
    data_to_display = data_to_display[
        data_to_display["PriceType"].isin(price_types)
    ].copy()

    # Sorting and cleaning up
    data_to_display.sort_values(["Municipality", "Year"], ascending=False, inplace=True)
    data_to_display.reset_index(inplace=True, drop=True)

    # Pivoting the data based on year
    data_to_display = data_to_display.pivot(
        index="Municipality", columns="Year", values=metric_for_use
    )

    # Calculating rate of change in the selected metric
    data_to_display["% change"] = (
        data_to_display[ref_year] - data_to_display[base_year]
    ) / data_to_display[base_year]
    data_to_display["% change"] = np.round(100 * data_to_display["% change"], 1)

    # Rounding off numbers before displaying the dataframe
    if metric_for_use == "AvgSalesPrice":
        for col in [base_year, ref_year]:
            data_to_display[col] = data_to_display[col].round(0).astype(int)
    else:
        for col in [base_year, ref_year]:
            data_to_display[col] = data_to_display[col].round(1)

    # Preparing string for displaying as a title of the table
    if metric_for_use == "AvgSalesPrice":
        txt_for_title = "actual price"
        txt_short = "price"
    elif metric_for_use == "M2AffordedTotal":
        txt_for_title = "buyable m² with annual income"
        txt_short = "affordability"
    elif metric_for_use == "YearsoBuy50M2Total":
        txt_for_title = "years of income to buy 50 m²"
        txt_short = "affordability"
    else:
        txt_for_title = "invalid selection"
        txt_short = "invalid selection"

    # Aggregating municipalities based on change type
    data_for_chart = data_to_display.reset_index().copy()
    conditions = [
        data_for_chart["% change"] < 0,
        data_for_chart["% change"] == 0,
        data_for_chart["% change"] > 0,
    ]
    values = [
        f"Decrease in {txt_for_title}",
        f"No change in {txt_for_title}",
        f"Increase in {txt_for_title}",
    ]
    data_for_chart["Change type"] = np.select(
        conditions, values, default="Unknown change"
    )
    data_for_chart = data_for_chart[
        data_for_chart["Municipality"] != "National average"
    ].copy()
    data_for_chart["Number of municipalities"] = data_for_chart.groupby("Change type")[
        "Municipality"
    ].transform("nunique")
    data_for_chart = data_for_chart.drop_duplicates("Change type")
    cols_to_keep = ["Change type", "Number of municipalities"]
    data_for_chart = data_for_chart[cols_to_keep]

    # =============================================
    # Showing overall insights based on change type
    # =============================================
    st.subheader(f"Overall changes in {txt_short}", divider="rainbow")
    st.write(
        f"""
            The chart below shows the number of municipalities that have
            seen either an increase/decrease in {txt_for_title}:"""
    )

    # Creating a doughnut chart with the split by change type
    chart = px.pie(
        data_for_chart,
        values="Number of municipalities",
        names="Change type",
        hole=0.45,
    )
    chart.update_layout(
        title_text=f"Number of municipalities split by type of change in {txt_for_title}",
        legend_title="",
    )
    st.plotly_chart(chart)

    # ==============================================
    # Showing detailed numbers for each municipality
    # ==============================================
    st.subheader(f"Changes in {txt_short} by municipality", divider="rainbow")
    st.write(
        f"""
            The **table** at the bottom shows data on {txt_for_title} in the
            selected baseline and reference (comparison) years, as well as the
            change between the two years measured in percentage terms:"""
    )

    # Displaying the full dataframe with all municipalities
    st.markdown(f"**Changes in {txt_for_title} between {base_year}-{ref_year}**")
    st.dataframe(data_to_display, use_container_width=True)

    # Displaying more details about how to use the chart
    st.markdown("**Please note that:**")
    st.write(
        """
        1) By default, the calculations nare based on actual sales prices per m²
        but you can also choose to focus on the two metrics of housing affordability
        seen throughout the rest of the app. To do so, use the 'Metric to show'
        filter in the sidebar.
        """
    )
    st.write(
        """
        2) Prices shown for each municipality are based on an annual weighted
        average, calculated based on sales in different post code areas. Some
        rounding off errors may persist.
        """
    )
    st.markdown(
        """
        3) We don't necessarily have data for all municipalities for all yeas,
        which is why some of the prices shown on the chart may be estimates rather
        than actual prices. Unlike on most other pages, filtering out estimated
        prices is not possible here, because it may mean we don't have enough data
        to show the comparisons.
        """
    )


# %% Page: annual price overview


def page_annual_price_overview(df):
    st.header("Overview of housing prices")
    add_logo()

    # Detecting and confirming slicer selections
    possible_years = (
        df[df["NationalDisposableTotalAvg"].notna()]["Year"].unique().tolist()
    )
    possible_mncp = df["Municipality"].unique().tolist()
    possible_years.sort(reverse=True)
    year_to_show = filter_by_specific_year(possible_years)
    price_types = filter_price_type_new(
        price_type_combinations, "Historical data incl. estimates"
    )
    metric_for_use = filter_metric(["Actual price", "Price index"])
    n_mncp_to_show = filter_by_n_mncp(possible_mncp, 10)

    st.write(
        """This page shows the development of the average sales price for
        flats in Denmark across time. In addition, it also shows the
        most and least expensive municipalities to buy an flat in."""
    )

    # Filtering the data
    data_to_display = df[df["PriceType"].isin(price_types)].copy()

    # Rounding off prices (0 decimals) and indices (2 decimals)
    if metric_for_use == "AvgSalesPrice":
        data_to_display[metric_for_use] = np.round(data_to_display[metric_for_use], 0)
        metric_for_use_txt = "Average price per m²"
    else:
        data_to_display[metric_for_use] = np.round(data_to_display[metric_for_use], 2)
        metric_for_use_txt = "Average price per m² (indexed)"

    # Preparing data for geo plot
    data_selected_year = data_to_display[
        data_to_display["PriceType"] == year_to_show
    ].copy()
    data_selected_year = data_selected_year[
        data_selected_year["Municipality"] != "National average"
    ].copy()

    # ===================================================================
    # Plotting historical development of the national average sales price
    # ===================================================================
    # Filtering the data
    data_for_plot = data_to_display[
        data_to_display["Municipality"] == "National average"
    ].copy()

    # Plotting the data on a chart
    fig1 = px.line(
        data_for_plot,
        x="Year",
        y=metric_for_use,
        labels={
            "Year": "Year",
            metric_for_use: metric_for_use_txt,
        },
    )
    fig1.update_layout({"title": "National average buying price per m² over time"})

    # Printing info for end user and chart
    st.subheader("Price development over time", divider="rainbow")
    st.markdown(
        """
                The chart below shows the development of **historical sales prices**
                over time by default. To display forecasts for the next few years,
                please enable this from the *Selected price type(s)* filter in the
                sidebar.
                """
    )
    st.plotly_chart(fig1)

    # ============================================
    # Plotting top N most expensive municipalities
    # ============================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("AvgSalesPrice", ascending=False, inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values(metric_for_use, inplace=True)

    # Plotting the data on a chart
    fig2 = px.bar(
        data_for_plot,
        x=metric_for_use,
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} most expensive municipalities in {year_to_show}",
        labels={
            "Municipality": "Municipality",
            metric_for_use: metric_for_use_txt,
        },
        color_discrete_sequence=["#EF553B"],
    )

    # Printing info for end user and chart
    st.subheader("Most expensive municipalities", divider="rainbow")
    st.markdown(
        """
                The chart below shows the **most expensive** municipalities to buy
                an flat in as of the year selected by the user. Please use
                the *Year* filter in the sidebar to look at a different period.
                If you want to display a different number of municipalities than
                the default, please use the *Number of top municipalities to show*
                filter in the sidebar.
                """
    )
    st.plotly_chart(fig2)

    # ======================================
    # Plotting top N cheapest municipalities
    # ======================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("AvgSalesPrice", inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values(metric_for_use, ascending=False, inplace=True)

    # Plotting the data on a chart
    fig3 = px.bar(
        data_for_plot,
        x=metric_for_use,
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} cheapest municipalities in {year_to_show}",
        labels={
            "Municipality": "Municipality",
            metric_for_use: metric_for_use_txt,
        },
        color_discrete_sequence=["#00CC96"],
    )

    # Printing info for end user and chart
    st.subheader("Cheapest municipalities", divider="rainbow")
    st.markdown(
        """
                The chart below shows the **least expensive** municipalities to buy
                an flat in as of the year selected by the user. Please use
                the filters in the sidebar to adjust the data displayed on it.
                """
    )
    st.plotly_chart(fig3)

    # ===========================================
    # Plotting top N mcp with highest price rises
    # ===========================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("AvgSalesPriceChange", ascending=False, inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values("AvgSalesPriceChange", inplace=True)

    # Plotting the data on a chart
    fig4 = px.bar(
        data_for_plot,
        x="AvgSalesPriceChange",
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} municipalities in {year_to_show} with the highest change in price per m² relative to 1992",
        labels={
            "Municipality": "Municipality",
            "AvgSalesPriceChange": "% change in average price per m²",
        },
    )

    # Printing info for end user and chart
    st.subheader("Municipalities with the highest price increase", divider="rainbow")
    st.markdown(
        """
        The chart below shows the municipalities where the **highest increase** in average sales price per m² is
        recorded, relative to the base year in the data (1992). Please use the filters in the sidebar
        to adjust the data displayed on the chart.
        """
    )
    st.plotly_chart(fig4)

    # ==========================================
    # Plotting top N mcp with lowest price rises
    # ==========================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("AvgSalesPriceChange", inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values("AvgSalesPriceChange", ascending=False, inplace=True)

    # Plotting the data on a chart
    fig5 = px.bar(
        data_for_plot,
        x="AvgSalesPriceChange",
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} municipalities in {year_to_show} with the lowest change in price per m² relative to 1992",
        labels={
            "Municipality": "Municipality",
            "AvgSalesPriceChange": "% change in average price per m²",
        },
    )

    # Printing info for end user and chart
    st.subheader("Municipalities with the lowest price increase", divider="rainbow")
    st.markdown(
        """
        The chart below shows the municipalities where the **lowest increase** in average sales price per m² is
        recorded, relative to the base year in the data (1992). Please use the filters in the sidebar
        to adjust the data displayed on the chart.
        """
    )
    st.plotly_chart(fig5)


# %% Page: annual affordability overview


def page_annual_afford_overview(df):
    st.header("Overview of housing affordability")
    add_logo()

    # Detecting and confirming slicer selections
    possible_years = (
        df[df["NationalDisposableTotalAvg"].notna()]["Year"].unique().tolist()
    )
    possible_mncp = df["Municipality"].unique().tolist()
    possible_years.sort(reverse=True)
    year_to_show = filter_by_specific_year(possible_years)
    price_types = filter_price_type_new(
        price_type_combinations, "Historical data incl. estimates"
    )
    n_mncp_to_show = filter_by_n_mncp(possible_mncp, 10)
    st.write(
        """This page provides an overview of the affordability of housing,
        which is calculated by relating the average sales price in each
        municipality to the local average disposable income."""
    )

    # Filtering the data
    data_to_display = df[df["PriceType"].isin(price_types)].copy()

    # Rounding off prices (0 decimals)
    data_to_display["M2AffordedTotal"] = np.round(data_to_display["M2AffordedTotal"], 0)

    # ============================================
    # Plotting top N most affordable municipalities
    # ============================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("M2AffordedTotal", ascending=False, inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values("M2AffordedTotal", inplace=True)

    # Plotting the data on a chart
    fig1 = px.bar(
        data_for_plot,
        x="M2AffordedTotal",
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} most affordable municipalities in {year_to_show}",
        labels={
            "Municipality": "Municipality",
            "M2AffordedTotal": "Buyable m² with annual income",
        },
        color_discrete_sequence=["#00CC96"],
    )

    # Printing info for end user and chart
    st.subheader("Most affordable municipalities", divider="rainbow")
    st.markdown(
        """
                The chart below shows the **most affordable** municipalities to buy
                an flat in as of the year selected by the user. Please use
                the filters in the sidebar to adjust the data displayed on it.
                """
    )
    st.plotly_chart(fig1)

    # ============================================
    # Plotting top N least affordable municipalities
    # ============================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("M2AffordedTotal", inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values("M2AffordedTotal", ascending=False, inplace=True)

    # Plotting the data on a chart
    fig2 = px.bar(
        data_for_plot,
        x="M2AffordedTotal",
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} least affordable municipalities in {year_to_show}",
        labels={
            "Municipality": "Municipality",
            "M2AffordedTotal": "Buyable m² with annual income",
        },
        color_discrete_sequence=["#EF553B"],
    )

    # Printing info for end user and chart
    st.subheader("Least affordable municipalities", divider="rainbow")
    st.markdown(
        """
                The chart below shows the **least affordable** municipalities to buy
                an flat in as of the year selected by the user. Please use
                the filters in the sidebar to adjust the data displayed on it.
                """
    )
    st.plotly_chart(fig2)

    # =============================================================
    # Plotting top N mcp with the best development in affordability
    # =============================================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("AvgM2AffordedTotalChange", ascending=False, inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values("AvgM2AffordedTotalChange", inplace=True)

    # Plotting the data on a chart
    fig3 = px.bar(
        data_for_plot,
        x="AvgM2AffordedTotalChange",
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} municipalities in {year_to_show} with the best development in affordability relative to 1992",
        labels={
            "Municipality": "Municipality",
            "AvgM2AffordedTotalChange": "% change in buyable m² with annual income",
        },
        color_discrete_sequence=["#00CC96"],
    )

    # Printing info for end user and chart
    st.subheader("Most positive development", divider="rainbow")
    st.markdown(
        """
        The chart below shows the municipalities where the **most positive**
        development in affordability is recorded. Development is measured as
        the percentage change in affordability between the selected year and
        the base year in the data (1992). Please use the filters in the sidebar
        to adjust the data displayed on the chart.
        """
    )
    st.plotly_chart(fig3)
    st.markdown(
        """*Note*: even though it's referred to as 'most positive
                development', in reality, this **does not mean** that it's become
                more affordable or cheaper to buy an flat. In some cases,
                this may even mean that relative to other municipalities, in the
                ones shown on the chart, flats have become less affordable
                at a slower rate."""
    )

    # ==============================================================
    # Plotting top N mcp with the worst development in affordability
    # ==============================================================
    # Filtering the data and sorting in the appropriate order
    data_for_plot = data_to_display[data_to_display["Year"] == year_to_show].copy()
    data_for_plot = data_for_plot[
        data_for_plot["Municipality"] != "National average"
    ].copy()
    data_for_plot.sort_values("AvgM2AffordedTotalChange", inplace=True)
    data_for_plot.reset_index(inplace=True, drop=True)
    data_for_plot = data_for_plot[:n_mncp_to_show].copy()
    data_for_plot.sort_values("AvgM2AffordedTotalChange", ascending=False, inplace=True)

    # Plotting the data on a chart
    fig4 = px.bar(
        data_for_plot,
        x="AvgM2AffordedTotalChange",
        y="Municipality",
        orientation="h",
        title=f"Top {n_mncp_to_show} municipalities in {year_to_show} with the worst development in affordability relative to 1992",
        labels={
            "Municipality": "Municipality",
            "AvgM2AffordedTotalChange": "% change in buyable m² with annual income",
        },
        color_discrete_sequence=["#EF553B"],
    )

    # Printing info for end user and chart
    st.subheader("Most negative development", divider="rainbow")
    st.markdown(
        """
        The chart below shows the municipalities where the **most negative**
        development in affordability is recorded, i.e. places where affordability
        has decreased at a higher rate relative to others. Development is measured as the percentage change in affordability between the selected year and
        the base year in the data (1992). Please use the filters in the sidebar
        to adjust the data displayed on the chart.
        """
    )
    st.plotly_chart(fig4)


# %% Page: Input data sources & quirks disclosure


def page_notes_data():
    st.header("Data collection & method")
    add_logo()
    st.markdown(
        """This page provides background information on where the data
        presented in this app comes from originally as well as what kind
        of transformations the data is subjected to before it is loaded
        in the app.
        """
    )
    st.markdown(
        """Please note that all price-related numbers used throughout
        the app are in Denmark's official currency, the **Danish krone (DKK)**
        and that all prices are of the **"current" type**, that is, they are not
        adjusted for the effects of inflation over time. This is done to ensure
        that the data points are directly comparable and that the numbers are
        identical to those used in the source.
        """
    )

    st.subheader("Data on sales prices", divider="rainbow")
    st.markdown(
        """Data on **prices of owned flats** (*ejerbolig* in Danish) comes
        from the `BM011` table on [Finans Danmark](rkr.statistikbank.dk)
        's website:
        """
    )
    st.markdown(
        """
        - Historical data is available starting from 1992 and up until the
        end of the most recent complete quarter.
        - Originally, the data comes in a quarterly format and is
        split by post code.
        - To transform it for use in this app, the post codes have been 
        grouped into their respective municipalities and the quarterly data 
        has been aggregated on an annual basis.
        - When doing the aggregation, we use the simple average for
        periods prior to 2004 and a weighted average for the year 2004 and
        thereafter. The weighted average approach improves data quality
        because it accounts for how many sales took place in each post code
        and not just their average price, but data on number of sales are
        not available before 2004, meaning we cannot use a weighted average
        before that year.
        - The price type exported is the *realiseret handelspris*,
        which means it's based on the final prices at which the flats
        were sold.

        Please note that this data is supplied by data on the **number of
        sold flats** in each post code and quarter, which are sourced from
        the `BM021` table on the [same website](rkr.statistikbank.dk).
        """
    )

    st.subheader("Data on disposable income", divider="rainbow")
    st.markdown(
        """Data on average disposable income by municipality is collected from the `INDKP101` table on [Danmarks Statistik (DST)](www.dst.dk)'s website.
        """
    )
    st.markdown(
        f"""
        - The data comes in an annual format and spans across 1987-{prev_year - 1} (new data is added in November, 2
        years after the fact, i.e. with quite a significant delay).
        - The data presents average disposable income in each municipality
        both in total but also divided by gender (male/female only).
        - It is furthermore possible to filter the data by age group and income
        level interval, however, this has not been deemed necessary for this app.
        """
    )

    st.subheader("Data on macroeconomic indicators", divider="rainbow")
    st.markdown(
        """Background data on most national **macroeconomic indicators**
                was collected from the most recent editions of the IMF's [World 
                Economic Outlook](https://www.imf.org/en/Publications/WEO):
                """
    )
    st.markdown(
        """
        - The data covers the period from 1980 onward, including both historical
        data and predictions for the upcoming 5 years.
        - The data used specifically in this app are the *Gross domestic 
        product* measured in nominal prices as well as *Inflation, end of
        period* measured in consumer prices.
        """
    )
    st.markdown(
        """Data on **interest rate** was collected from the `MPK3` table
                on [Danmarks Statistik (DST)](www.dst.dk)'s website:
                """
    )
    st.markdown(
        """
        - The data is available on a monthly basis starting from 1985 and up
        until the end of the most recent complete month.
        - The data is aggregated at the annual level using its median value.
        - The data type downloaded is *Nationalbankens diskonto*, which is the
        rate that banks in Denmark use as a starting point as it stems from
        Denmark's National Bank.
        """
    )


# %% Page: Model fit metrics disclosure


def page_notes_accuracy(income_fit_metrics, price_imp_metrics, price_fit_metrics):
    st.header("Info on model accuracy & method")
    add_logo()
    st.markdown(
        """The data presented in this app has been subjected to **several
        different models** in order for the app to be able to show e.g.
        uninterrupted historical data or predictions for the future.
        Naturally, these models introduce some degree of **uncertainty** to
        some of the numbers presented. To increase **transparency**, the
        accuracy metrics related to all models applied to the raw data
        are reported below."""
    )

    # Sidebar filter determining the kind of metrics to show
    selected_metrics = filter_fit_metrics("Accuracy (%) only")

    # Displaying background info on the predictions for disposable income
    st.subheader("Predictions for disposable income", divider="rainbow")
    st.markdown(
        f"""DST provides data on disposable income with a **significant
        delay**, for example, the data for {prev_year} will only be published in
        November {current_year}. In addition, no data on **future disposable income**
        is available in the source but as certain calculations depend on knowing 
        future income levels (e.g. future housing affordability),
        we need to generate predictions for future disposable income as well.
        """
    )
    st.markdown(
        """
        * **Predictions are generated by** fitting a separate OLS regression model
        for each municipality, where local disposable income is modelled as a
        *function of Denmark's national GDP*.
        * The **accuracy** of the model is then evaluated using the inverse of the
        mean absolute percentage error (**MAPE**) score, which shows by how much
        the income predicted by the model differs from the observed income in the
        historical data.
        * The **R²** metric shows how much of the change in local income can be
        explained by its relationship to Denmark's national GDP.
        """
    )

    # Displaying model fit metrics for the disposable income predictions
    st.markdown("**You can see the model's accuracy for each municipality below:**")
    if selected_metrics == "Accuracy (%) only":
        cols_to_keep = [col for col in income_fit_metrics if "Accuracy" in col]
        cols_to_keep = ["Municipality"] + cols_to_keep
        data_to_display = income_fit_metrics[cols_to_keep]
    elif selected_metrics == "R² only":
        cols_to_keep = [col for col in income_fit_metrics if "R²" in col]
        cols_to_keep = ["Municipality"] + cols_to_keep
        data_to_display = income_fit_metrics[cols_to_keep]
    elif selected_metrics == "MAPE/RMSE only":
        cols_to_keep = [
            col for col in income_fit_metrics if "MAPE" in col or "RMSE" in col
        ]
        cols_to_keep = ["Municipality"] + cols_to_keep
        data_to_display = income_fit_metrics[cols_to_keep]
    else:
        data_to_display = income_fit_metrics
    st.dataframe(data_to_display, hide_index=True)

    # Displaying background info on the predictions for future sales price
    st.subheader("Predictions for future sales price", divider="rainbow")
    st.markdown(
        """Finans Danmark does not provide predictions for future sales prices, though
        exploring how historical trends might translate into the future can
        be a valuable insight. Therefore, additional predictive models were
        included in here so that we can get an estimate of not only what future
        sales prices might look like but also what housing affordability might be.
        """
    )
    st.markdown(
        f"""
        * **Predictions are generated by** fitting a separate OLS regression model
        for each municipality, where local average sales price is modelled as a
        function of Denmark's national *GDP*, *annual inflation* and the annual
        *median interest rate* as reported by Denmark's national bank.
        * The **future values** of GDP and inflation are sourced from the IMF's
        World Economic Outlook (published in April and October each year), while for interest rate,
        we use the all-time historical average of {med_int}%.
        * The **accuracy** of the model is then evaluated using the inverse of the
        mean absolute percentage error (**MAPE**) score, which shows by how much
        the price predicted by the model differs from the observed price in the
        historical data.
        * The **R²** metric shows how much of the change in sales price can be
        explained by its relationship to Denmark's national GDP, annual inflation
        and annual median interest rate.
        """
    )

    # Displaying model fit metrics for the disposable income predictions
    st.markdown("**You can see the model's accuracy for each municipality below:**")
    if selected_metrics == "Accuracy (%) only":
        cols_to_keep = [col for col in price_fit_metrics if "Accuracy" in col]
        cols_to_keep = ["Municipality"] + cols_to_keep
        data_to_display = price_fit_metrics[cols_to_keep]
    elif selected_metrics == "R² only":
        cols_to_keep = [col for col in price_fit_metrics if "R²" in col]
        cols_to_keep = ["Municipality"] + cols_to_keep
        data_to_display = price_fit_metrics[cols_to_keep]
    elif selected_metrics == "MAPE/RMSE only":
        cols_to_keep = [
            col for col in price_fit_metrics if "MAPE" in col or "RMSE" in col
        ]
        cols_to_keep = ["Municipality"] + cols_to_keep
        data_to_display = price_fit_metrics[cols_to_keep]
    else:
        data_to_display = price_fit_metrics
    st.dataframe(data_to_display, hide_index=True)

    # Displaying background info on the imputations in historical sales price
    st.subheader("Imputations in historical prices", divider="rainbow")
    st.markdown(
        """The way Finans Danmark measures sales prices is based on actual sales, however,
        it is not always the case that sales have been realized in every 
        municipality in each year. Furthermore, sometimes the number of realized
        sales is too low and Finans Danmark choses not to disclose the price. To be able
        to show uninterrupted historical data even in cases where no actual sales
        data is available in the source, a special algorithm was used to generate
        the approximate sales prices in those cases where they were missing.
        """
    )
    st.markdown(
        """
        * **Imputations were made using** a random forest algorithm (`missForest`),
        which was applied across municipalities to ensure prices in any given year
        were comparable. The algorithm estimated the missing prices based on other
        known values such as the national average sales price, the total number of
        sales in the year as well as the local level of disposable income and
        its relationship with the national level of income.
        * The **accuracy** of the model is then evaluated using the inverse of the
        normalized root of the mean squared error (**RMSE**) score, which shows by 
        how much the model's output differs from the observed price in the
        historical data. This was used as a substitute for the MAPE score as the
        imputation algorithm (`missForest`) does not provide the latter.
        """
    )

    # Displaying model fit metrics for the historical sales price imputation
    st.markdown("**You can see the model's overall accuracy below:**")
    if selected_metrics == "Accuracy (%) only":
        allowed_metrics = ["Accuracy (%)"]
        data_to_display = price_imp_metrics[
            price_imp_metrics.index.isin(allowed_metrics)
        ]
    elif selected_metrics == "R² only":
        st.warning(
            """Note: R² is not available for this model. Please select a different metric to show.
            """
        )
    elif selected_metrics == "MAPE/RMSE only":
        allowed_metrics = ["Normalized RMSE (%)"]
        data_to_display = price_imp_metrics[
            price_imp_metrics.index.isin(allowed_metrics)
        ]
    else:
        data_to_display = price_imp_metrics
    st.dataframe(data_to_display, hide_index=True)

    # Closing words on uncertainty
    st.subheader("On the impact of uncertainty", divider="rainbow")
    st.markdown(
        """Uncertainty may impact the numbers shown in this app in two main ways:
        """
    )
    st.markdown(
        """
        - First, because we have some **missing data** for historical sales prices,
        we have had to restort to imputing them. Although the algorithm used has
        provided reasonable values for those cases where they were missing in the
        source, the real prices in that period are unknown and the model can only
        provide approximations.
        - Second, because future prices are predicted based on **historical
        trends**, these numbers are valid only so far as the assumption that
        historical trends will continue into the future holds true.
        """
    )
    st.markdown(
        """
        As the numbers may in some cases be impacted by uncertainty,
        a **complete disclosure** of the model accuracy has been made.
        """
    )
    st.markdown(
        """
        All in all, while the models applied to transform the data may introduce
        some uncertainty to the numbers displayed, they also bring about **important
        improvements** such as the ability to show continuous historical data for
        all municipalities as well as the ability to get an idea of what future
        sales prices might look like.
        """
    )


# %% Compulsory legal disclaimer


def page_legal():
    st.header("Legal disclaimer")
    add_logo()
    st.markdown(
        """
    This application is intended for educational purposes only and is designed to 
    benefit the general public.
    
    **By using this application, you acknowledge and agree to the following terms**:
                
    1. The app **gives an insight** into the development in the sales price of
    so-called "owned flats" (*ejerbolig* in Danish) and local disposable
    income in each municipality, using the two to derive a metric of housing
    affordability.
    2. The intent of the author is to **empower the general public** (which 
    suffers as a direct consquence of rising unaffordability) and **decision-makers**
    (who may take measures to make housing more affordable for the average resident).
    3. Due to the nature of the data, which is not always available in the source
    and which is subjected to aggregation in connection with this app, the numbers
    provided in here are **approximations rather than 100% exact numbers**.
    4. The author **does not claim ownership** for any of the input data used in the
    app, the sources of which are credited on the "Info on data sources" page.
    5. The numbers generated in the subsequent data processing and modelling,
    including imputed values of historical sales prices as well as predictions
    for future sales price may be **distributed further** only by referencing
    this app and its author.
    6. The data and insights provided by this application are **not intended for
    commercial use**.
    7. While every effort has been made to ensure the accuracy and reliability of
    the data, the creator of this application **does not guarantee** the accuracy,
    completeness, or suitability of the data for any particular purpose.
    8. The creator **shall not be held liable for** any loss, damage,
    or inconvenience arising as a consequence of any use of or the inability to
    use any information provided by this application, including using the forecasted
    future prices to make decisions about selling/purchasing flats in real life.

    These terms were last revised on 09 April 2025.
"""
    )


# %% Allowing the user to switch between pages in the app

# Based on the page selected by the end user
if options == "Welcome":
    show_homepage()
elif options == "Pricing overview":
    page_annual_price_overview(sales_data)
elif options == "Affordability overview":
    page_annual_afford_overview(sales_data)
elif options == "Pricing by municipality":
    page_avg_by_mncp(sales_data)
elif options == "Affordability by municipality":
    page_afford_by_mncp(sales_data)
elif options == "Affordability by gender":
    page_afford_by_mncp_gen(sales_data)
elif options == "Indexed developments":
    page_indexed_dev(indexed_development)
elif options == "Historical changes":
    page_hist_changes(sales_data)
elif options == "Info on data sources":
    page_notes_data()
elif options == "Info on modelling":
    page_notes_accuracy(income_fit_metrics, price_imp_metrics, price_fit_metrics)
elif options == "Legal disclaimer":
    page_legal()
