
<!-- README.md is generated from README.Rmd. Please edit that file -->

# TrackValue: Clinical Trial Transparency

This repository supports the clinical trial transparency report card
project within TrackValue.

## Trials

The dataset is based on
[IntoValue](https://doi.org/10.5281/zenodo.5141343) with updated data;
see [`intovalue-data` repo](https://github.com/maia-sh/intovalue-data)
for futher details on the dataset. IntoValue inclusion criteria for
completion date (2008-2018), completion status, and interventional are
reapplied on trials with updated registry data.

The data was last updated on the following dates:

-   PubMed: 2021-08-15
-   AACT (ClinicalTrials.gov): 2021-08-15
-   DRKS: 2021-08-15
-   Unpaywall: 2022-02-20
-   ShareYourPaper: 2022-02-20

For TrackValue, we are interested in Charité-affiliated trials from
recent years (i.e., more likely PIs are still at Charité), and so limit
to IntoValue 2 trials with Charité listed as a lead city.

The TrackValue dataset consists of 170 trials, including 149 trials from
ClinicalTrials.gov and 21 trials from DRKS.

## Report card transparency elements

TrackValue clinical trial transparency report cards may include various
transparency elements. The current frontrunners are: summary results
reporting, publication linkage in registry, and open access. All
potential elements are included below.

### Outline

-   registration (boolean)

    -   if registration –&gt; registration (timely)

-   summary results (boolean)

    -   if summary results –&gt; summary results (timely)

-   publication (boolean)

    -   if publication –&gt; publication (timely)

    -   if publication –&gt; trn in journal publication (full-text)

    -   if publication –&gt; trn in journal publication (abstract)

    -   if publication –&gt; publication in registration

    -   if publication –&gt; open access (closed/open)

        -   if publication –&gt; if closed –&gt; open access (can/not be
            archived)

As such, some report cards would be a short as 3 items (registration
timeliness, no summary results, no publication) and some as long as 10
items (registration timeliness, summary results, publication closed).

### Table

The table below provides an overview of the percentage and number of
trials per registry which comply with each element.

| **TrackValue trials transparency elements** | **Overall**, N = 170 | **ClinicalTrials.gov**, N = 149 | **DRKS**, N = 21 |
|:--------------------------------------------|:---------------------|:--------------------------------|:-----------------|
| **Prospective registration, n (%)**         | 105 (62%)            | 97 (65%)                        | 8 (38%)          |
| **Has registry summary results, n (%)**     | 18 (11%)             | 17 (11%)                        | 1 (4.8%)         |
| **Timely summary results (12 mo), n (%)**   | 10 (56%)             | 10 (59%)                        | 0 (0%)           |
| Unknown                                     | 152                  | 132                             | 20               |
| **Timely summary results (24 mo), n (%)**   | 16 (89%)             | 15 (88%)                        | 1 (100%)         |
| Unknown                                     | 152                  | 132                             | 20               |
| **Has publication, n (%)**                  | 108 (64%)            | 92 (62%)                        | 16 (76%)         |
| **Timely publication (24 mo), n (%)**       | 59 (52%)             | 50 (51%)                        | 9 (56%)          |
| Unknown                                     | 56                   | 51                              | 5                |
| **TRN reported in abstract, n (%)**         | 41 (38%)             | 39 (42%)                        | 2 (12%)          |
| Unknown                                     | 62                   | 57                              | 5                |
| **TRN reported in full-text, n (%)**        | 61 (56%)             | 54 (59%)                        | 7 (44%)          |
| Unknown                                     | 62                   | 57                              | 5                |
| **Publication linked in registry, n (%)**   | 56 (50%)             | 51 (53%)                        | 5 (31%)          |
| Unknown                                     | 57                   | 52                              | 5                |
| **Openly accessible, n (%)**                | 68 (61%)             | 60 (63%)                        | 8 (50%)          |
| Unknown                                     | 59                   | 54                              | 5                |
| **Closed, archivable, n (%)**               | 40 (100%)            | 34 (100%)                       | 6 (100%)         |
| Unknown                                     | 130                  | 115                             | 15               |

## Trials for intervention outcome measures

Summary results reporting: 152

Publication link in registration: 52

Green OA publication: 37

## EUCTR and other cross-registrations

The IntoValue, and hence TrackValue, sample includes trials any
interventional study in the registry and is not limited to those
regulated by German drug and medical laws. Trials regulated by those
rules *should* be registered in EUCTR, rather than ClinicalTrials.gov or
DRKS. As such, trials in our sample which are cross-registered in EUCTR
are perhaps more likely clinical trials per German law (and may be more
likely to fulfil transparency requirements - note: todo).

We found that 27 (16%) trials in our sample include one or more EUCTR
ids in their registration, and are presumably cross-registered in EUCTR.
This includes 23 (15%) trials from ClinicalTrials.gov and 4 (19%) trials
from DRKS.

Considering TRNs both in the registry as well as in the publication, we
find additional potential cross-registrations in EUCTR as well as in
other registries (N = 41).

| crossreg\_registry | n\_crossreg |
|:-------------------|------------:|
| EudraCT            |          38 |
| ClinicalTrials.gov |          17 |
| DRKS               |           5 |
| ISRCTN             |           1 |
