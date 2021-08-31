
<!-- README.md is generated from README.Rmd. Please edit that file -->

# TrackValue: Clinical Trial Transparency

This repository supports the clinical trial transparency report card
project within TrackValue.

## Trials

The dataset is based on
[IntoValue](https://doi.org/10.5281/zenodo.5141343) with updated data;
see [`intovalue-data` repo](https://github.com/maia-sh/intovalue-data))
for futher details on the dataset. IntoValue inclusion criteria for
completion date (2008-2018), completion status, and interventional are
reapplied on trials with updated registry data.

The data was last updated on the following dates:

-   PubMed: 2021-08-15
-   AACT (ClinicalTrials.gov): 2021-08-15
-   DRKS: 2021-08-15
-   Unpaywall: 2021-08-15
-   ShareYourPaper: 2021-07-23

For TrackValue, we are interested in Charité-affiliated trials from
recent years (i.e., more likely PIs are still at Charité), and so limit
to IntoValue 2 trials with Charité listed as a lead city.

The TrackValue dataset consists of 171 trials, including 150 trials from
ClinicalTrials.gov and 21 trials from DRKS.

## Report card transparency elements

TrackValue clinical trial transparency report cards may include various
transparency elements. The current frontrunners are: summary results
reporting, publication linkage in registry, and open access. All
potential elements are included below.

### Outline

-   registration (boolean)

    -   if registration –> registration (timely)

-   summary results (boolean)

    -   if summary results –> summary results (timely)

-   publication (boolean)

    -   if publication –> publication (timely)

    -   if publication –> trn in journal publication (full-text)

    -   if publication –> trn in journal publication (abstract)

    -   if publication –> publication in registration

    -   if publication –> open access (closed/open)

        -   if publication –> if closed –> open access (can/not be
            archived)

As such, some report cards would be a short as 3 items (registration
timeliness, no summary results, no publication) and some as long as 10
items (registration timeliness, summary results, publication closed).

### Table

The table below provides an overview of the percentage and number of
trials per registry which comply with each element.

| **TrackValue trials transparency elements** | **ClinicalTrials.gov**, N = 150 | **DRKS**, N = 21 |
|:--------------------------------------------|:--------------------------------|:-----------------|
| **Prospective registration, n (%)**         | 98 (65%)                        | 8 (38%)          |
| **Has registry summary results, n (%)**     | 17 (11%)                        | 1 (4.8%)         |
| **Timely summary results (12 mo), n (%)**   | 10 (59%)                        | 0 (0%)           |
| Unknown                                     | 133                             | 20               |
| **Timely summary results (24 mo), n (%)**   | 15 (88%)                        | 1 (100%)         |
| Unknown                                     | 133                             | 20               |
| **Has publication, n (%)**                  | 96 (64%)                        | 16 (76%)         |
| **Timely publication (24 mo), n (%)**       | 50 (51%)                        | 9 (56%)          |
| Unknown                                     | 52                              | 5                |
| **TRN reported in abstract, n (%)**         | 39 (43%)                        | 1 (6.7%)         |
| Unknown                                     | 59                              | 6                |
| **TRN reported in full-text, n (%)**        | 53 (58%)                        | 6 (40%)          |
| Unknown                                     | 59                              | 6                |
| **Publication linked in registry, n (%)**   | 51 (53%)                        | 5 (31%)          |
| Unknown                                     | 54                              | 5                |
| **Openly accessible, n (%)**                | 49 (52%)                        | 6 (38%)          |
| Unknown                                     | 55                              | 5                |
| **Closed, archivable, n (%)**               | 42 (98%)                        | 9 (100%)         |
| Unknown                                     | 107                             | 12               |

## EUCTR

The IntoValue, and hence TrackValue, sample includes trials any
interventional study in the registry and is not limited to those
regulated by German drug and medical laws. Trials regulated by those
rules *should* be registered in EUCTR, rather than ClinicalTrials.gov or
DRKS. As such, trials in our sample which are cross-registered in EUCTR
are perhaps more likely clinical trials per German law.

We found that 27 (16%) trials in our sample include an EUCTR id in their
registration, and are presumably cross-registered in EUCTR. This
includes 23 (15%) trials from ClinicalTrials.gov and 4 (19%) trials from
DRKS.

## Open Questions

-   [ ] Timely summary results within 1 or 2 years? Or could use
    continuous time.
-   [ ] Should we exclude trials likely cross-registered in EUCTR?
