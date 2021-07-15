
<!-- README.md is generated from README.Rmd. Please edit that file -->

# TrackValue: Clinical Trial Transparency

This repository supports the clinical trial transparency report card
project within TrackValue.

## Trials

The dataset is based on IntoValue with updated registry
(ClinicalTrials.gov and DRKS) data from 2021-05-15 (see
[`intovalue-data` repo](https://github.com/maia-sh/intovalue-data)).
IntoValue inclusion criteria for completion date (2008-2018), status
(\~completed), and interventional are reapplied on trials with updated
registry data.

For TrackValue, we are interested in Charité-affiliated trials from
recent years (i.e., more likely PIs are still at Charité), and so limit
to IntoValue 2 trials with Charité listed as a lead city.

The TrackValue dataset consists of 172 trials, including 151 trials from
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

| **TrackValue trials transparency elements** | **ClinicalTrials.gov**, N = 151 | **DRKS**, N = 21 |
|:--------------------------------------------|:--------------------------------|:-----------------|
| **Prospective registration, n (%)**         | 99 (66%)                        | 8 (38%)          |
| **Has registry summary results, n (%)**     | 16 (11%)                        | 1 (4.8%)         |
| **Timely summary results (12 mo), n (%)**   | 0 (NA%)                         | 0 (0%)           |
| Unknown                                     | 151                             | 20               |
| **Timely summary results (24 mo), n (%)**   | 0 (NA%)                         | 1 (100%)         |
| Unknown                                     | 151                             | 20               |
| **Has publication, n (%)**                  | 99 (66%)                        | 16 (76%)         |
| **Timely publication (24 mo), n (%)**       | 51 (52%)                        | 9 (56%)          |
| Unknown                                     | 52                              | 5                |
| **TRN reported in abstract, n (%)**         | 39 (42%)                        | 1 (6.7%)         |
| Unknown                                     | 59                              | 6                |
| **TRN reported in full-text, n (%)**        | 53 (58%)                        | 6 (40%)          |
| Unknown                                     | 59                              | 6                |
| **Publication linked in registry, n (%)**   | 53 (55%)                        | 5 (31%)          |
| Unknown                                     | 54                              | 5                |
| **Openly accessible, n (%)**                | 58 (60%)                        | 8 (50%)          |
| Unknown                                     | 55                              | 5                |
| **Closed, archivable, n (%)**               | 33 (94%)                        | 6 (86%)          |
| Unknown                                     | 116                             | 14               |

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
