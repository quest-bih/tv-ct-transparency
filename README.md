
<!-- README.md is generated from README.Rmd. Please edit that file -->

# TrackValue: Clinical Trial Transparency

This repository supports the clinical trial transparency report card
project within TrackValue.

## Trials

The dataset is based on IntoValue with updated registry
(ClinicalTrials.gov and DRKS) data from 2021-05-15 (see `intovalue-data`
repo). IntoValue inclusion criteria for completion date (2008-2018),
status (\~completed), and interventional are reapplied on trials with
updated registry data.

For TrackValue, we are interested in Charité-affiliated trials from
recent years (i.e., more likely PIs are still at Charité), and so limit
to IntoValue 2 trials with Charité listed as a lead city.

``` r
trackvalue <-
  read_rds(here::here("data", "processed", "trackvalue.rds"))

n_ctgov <-
  trackvalue %>% 
  filter(registry == "ClinicalTrials.gov") %>% 
  nrow()

n_drks <-
  trackvalue %>% 
  filter(registry == "DRKS") %>% 
  nrow()
```

The TrackValue dataset consists of 172 trials, including 151 trials from
ClinicalTrials.gov and 21 trials from DRKS.

## Report card transparency elements

TrackValue clinical trial transparency report cards may include various
transparency elements. The current frontrunners are: summary results
reporting, publication linkage in registry, and open access. The table
below provides an overview of the percentage and number of trials per
registry which comply with each element.

``` r
trackvalue %>%

  # Create booleans for whether results are timely
  #TODO: Team decision, how to decide timeliness? use days or months like with is_prospective? For now use days but may not be the keeper
  # Note: We don't have DRKS summary results dates so will all be NA
  # TODO: Team decision: whether to manually get summary results date and whether from pdf or history. N = 1 in our sample!
  mutate(
    is_timely_summary_results = if_else(days_cd_to_summary <= 365, TRUE, FALSE),
    is_timely_publication = if_else(days_cd_to_publication <= 2*365, TRUE, FALSE)
  ) %>%

  select(
    registry,
    is_prospective,
    has_publication,
    is_timely_publication,
    has_summary_results,
    is_timely_summary_results,
    has_reg_pub_link,
    has_iv_trn_abstract,
    has_iv_trn_ft_pdf
  ) %>%
  gtsummary::tbl_summary(
    by = registry,
    label = list(
      is_prospective ~ "Prospective registration",
      has_publication ~ "Has publication",
      is_timely_publication ~ "Timely publication (24 mo)",
      has_summary_results  ~ "Has registry summary results",
      is_timely_summary_results ~ "Timely summary results (12 mo)",
      has_reg_pub_link  ~ "Publication linked in registry",
      has_iv_trn_abstract ~ "TRN reported in abstract",
      has_iv_trn_ft_pdf ~ "TRN reported in full-text"
    )
  ) %>%

  # Move stats legend to each line
  add_stat_label() %>%

  modify_header(label = "**TrackValue trials transparency elements**") %>%

  bold_labels()
#> Warning: The `.dots` argument of `group_by()` is deprecated as of dplyr 1.0.0.
```

<style>html {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', 'Fira Sans', 'Droid Sans', Arial, sans-serif;
}

#qmdhzujbqi .gt_table {
  display: table;
  border-collapse: collapse;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#qmdhzujbqi .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#qmdhzujbqi .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#qmdhzujbqi .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 0;
  padding-bottom: 4px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#qmdhzujbqi .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#qmdhzujbqi .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#qmdhzujbqi .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#qmdhzujbqi .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#qmdhzujbqi .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#qmdhzujbqi .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#qmdhzujbqi .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#qmdhzujbqi .gt_group_heading {
  padding: 8px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
}

#qmdhzujbqi .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#qmdhzujbqi .gt_from_md > :first-child {
  margin-top: 0;
}

#qmdhzujbqi .gt_from_md > :last-child {
  margin-bottom: 0;
}

#qmdhzujbqi .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#qmdhzujbqi .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 12px;
}

#qmdhzujbqi .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#qmdhzujbqi .gt_first_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
}

#qmdhzujbqi .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#qmdhzujbqi .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#qmdhzujbqi .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#qmdhzujbqi .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#qmdhzujbqi .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#qmdhzujbqi .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding: 4px;
}

#qmdhzujbqi .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#qmdhzujbqi .gt_sourcenote {
  font-size: 90%;
  padding: 4px;
}

#qmdhzujbqi .gt_left {
  text-align: left;
}

#qmdhzujbqi .gt_center {
  text-align: center;
}

#qmdhzujbqi .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#qmdhzujbqi .gt_font_normal {
  font-weight: normal;
}

#qmdhzujbqi .gt_font_bold {
  font-weight: bold;
}

#qmdhzujbqi .gt_font_italic {
  font-style: italic;
}

#qmdhzujbqi .gt_super {
  font-size: 65%;
}

#qmdhzujbqi .gt_footnote_marks {
  font-style: italic;
  font-size: 65%;
}
</style>
<div id="qmdhzujbqi" style="overflow-x:auto;overflow-y:auto;width:auto;height:auto;"><table class="gt_table">
  
  <thead class="gt_col_headings">
    <tr>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1"><strong>TrackValue trials transparency elements</strong></th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1"><strong>ClinicalTrials.gov</strong>, N = 151</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1"><strong>DRKS</strong>, N = 21</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td class="gt_row gt_left" style="font-weight: bold;">Prospective registration, n (%)</td>
<td class="gt_row gt_center">99 (66%)</td>
<td class="gt_row gt_center">8 (38%)</td></tr>
    <tr><td class="gt_row gt_left" style="font-weight: bold;">Has publication, n (%)</td>
<td class="gt_row gt_center">99 (66%)</td>
<td class="gt_row gt_center">16 (76%)</td></tr>
    <tr><td class="gt_row gt_left" style="font-weight: bold;">Timely publication (24 mo), n (%)</td>
<td class="gt_row gt_center">51 (52%)</td>
<td class="gt_row gt_center">9 (56%)</td></tr>
    <tr><td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">Unknown</td>
<td class="gt_row gt_center">52</td>
<td class="gt_row gt_center">5</td></tr>
    <tr><td class="gt_row gt_left" style="font-weight: bold;">Has registry summary results, n (%)</td>
<td class="gt_row gt_center">16 (11%)</td>
<td class="gt_row gt_center">1 (4.8%)</td></tr>
    <tr><td class="gt_row gt_left" style="font-weight: bold;">Timely summary results (12 mo), n (%)</td>
<td class="gt_row gt_center">10 (62%)</td>
<td class="gt_row gt_center">0 (NA%)</td></tr>
    <tr><td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">Unknown</td>
<td class="gt_row gt_center">135</td>
<td class="gt_row gt_center">21</td></tr>
    <tr><td class="gt_row gt_left" style="font-weight: bold;">Publication linked in registry, n (%)</td>
<td class="gt_row gt_center">53 (55%)</td>
<td class="gt_row gt_center">5 (31%)</td></tr>
    <tr><td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">Unknown</td>
<td class="gt_row gt_center">54</td>
<td class="gt_row gt_center">5</td></tr>
    <tr><td class="gt_row gt_left" style="font-weight: bold;">TRN reported in abstract, n (%)</td>
<td class="gt_row gt_center">39 (42%)</td>
<td class="gt_row gt_center">1 (6.7%)</td></tr>
    <tr><td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">Unknown</td>
<td class="gt_row gt_center">59</td>
<td class="gt_row gt_center">6</td></tr>
    <tr><td class="gt_row gt_left" style="font-weight: bold;">TRN reported in full-text, n (%)</td>
<td class="gt_row gt_center">53 (58%)</td>
<td class="gt_row gt_center">6 (40%)</td></tr>
    <tr><td class="gt_row gt_left" style="text-align: left; text-indent: 10px;">Unknown</td>
<td class="gt_row gt_center">59</td>
<td class="gt_row gt_center">6</td></tr>
  </tbody>
  
  
</table></div>

## EUCTR

The IntoValue, and hence TrackValue, sample includes trials any
interventional study in the registry and is not limited to those
regulated by German drug and medical laws. Trials regulated by those
rules *should* be registered in EUCTR, rather than ClinicalTrials.gov or
DRKS. As such, trials in our sample which are cross-registered in EUCTR
are perhaps more likely clinical trials per German law.

``` r
crossreg <-
  read_rds(here::here("data", "processed", "crossreg.rds"))

tv_euctr_crossreg <-
  crossreg %>%
  
  # Limit to EUCTR cross-registrations (in registry)
  filter(crossreg_registry == "EudraCT" & is_crossreg_reg) %>%
  
  # Add in registry
  left_join(select(trackvalue, id, registry), by = "id") %>% 
  
  # Assert that there is max 1 EUCTR cross-registration per trial
  assertr::assert(assertr::is_uniq, id)

n_euctr_ctgov <-
  tv_euctr_crossreg %>% 
  filter(registry == "ClinicalTrials.gov") %>% 
  nrow()

n_euctr_drks <-
  tv_euctr_crossreg %>% 
  filter(registry == "DRKS") %>% 
  nrow()
```

We found that 27 trials in our sample include an EUCTR id in their
registration, including 23 trials from ClinicalTrials.gov and 4 trials
from DRKS.

## Open Questions

-   [ ] How to decide timeliness (i.e., `is_timely_summary_results` and
    `is_timely_publication`)? Option 1 would be to use days (i.e.,
    `days_cd_to_summary` and `days_cd_to_publication`) compared with 365
    and 265 times 2 respectivel. Option 2 would be to use a rough/more
    generous month or year cut (similar to `is_prospective`). Currently,
    determine based on days.
-   [ ] Our sample does not include dates for DRKS summary results, so
    that and associated metrics are NA. Should we manually add the
    summary results date to the TV trial (N = 1)? If so, using the PDF
    date or the DRKS changes history date?
