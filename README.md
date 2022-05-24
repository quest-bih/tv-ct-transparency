
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

-   PubMed: 2022-05-19
-   AACT (ClinicalTrials.gov): 2022-05-19
-   DRKS: 2022-05-19
-   Unpaywall: 2022-05-19
-   ShareYourPaper: 2022-05-19

For TrackValue, we are interested in Charité-affiliated trials from
recent years (i.e., more likely PIs are still at Charité), and so limit
to IntoValue 2 trials with Charité listed as a lead city.

The TrackValue dataset consists of 168 trials, including 149 trials from
ClinicalTrials.gov and 19 trials from DRKS.

## Report card transparency practices

TrackValue clinical trial transparency report cards include the
following practices:

-   registration (boolean)

    -   if registration –\> registration (timely)

-   summary results (boolean)

    -   if summary results –\> summary results (timely)

-   publication (boolean)

    -   if publication –\> publication (timely)

    -   if publication –\> trn in journal publication (full-text)

    -   if publication –\> trn in journal publication (abstract)

    -   if publication –\> publication in registration

    -   if publication –\> open access (closed/open)

        -   if publication –\> if closed –\> open access (can/not be
            archived)

### Table

The table below provides an overview of the percentage and number of
trials per registry which comply with each element.

| **TrackValue trials transparency elements** | **Overall**, N = 168 | **ClinicalTrials.gov**, N = 149 | **DRKS**, N = 19 |
|:--------------------------------------------|:--------------------:|:-------------------------------:|:----------------:|
| **Prospective registration, n (%)**         |      104 (62%)       |            97 (65%)             |     7 (37%)      |
| **Has registry summary results, n (%)**     |       18 (11%)       |            18 (12%)             |      0 (0%)      |
| **Timely summary results (12 mo), n (%)**   |       10 (53%)       |            10 (56%)             |      0 (0%)      |
| Unknown                                     |         149          |               131               |        18        |
| **Timely summary results (24 mo), n (%)**   |       16 (84%)       |            15 (83%)             |     1 (100%)     |
| Unknown                                     |         149          |               131               |        18        |
| **Has publication, n (%)**                  |      108 (64%)       |            93 (62%)             |     15 (79%)     |
| **Timely publication (24 mo), n (%)**       |       60 (53%)       |            51 (52%)             |     9 (60%)      |
| Unknown                                     |          55          |               51                |        4         |
| **TRN reported in abstract, n (%)**         |       41 (38%)       |            39 (41%)             |     2 (13%)      |
| Unknown                                     |          59          |               55                |        4         |
| **TRN reported in full-text, n (%)**        |       60 (55%)       |            53 (56%)             |     7 (47%)      |
| Unknown                                     |          59          |               55                |        4         |
| **Publication linked in registry, n (%)**   |       54 (47%)       |            54 (55%)             |      0 (0%)      |
| Unknown                                     |          54          |               50                |        4         |
| **Openly accessible, n (%)**                |       72 (64%)       |            65 (67%)             |     7 (47%)      |
| Unknown                                     |          56          |               52                |        4         |
| **Closed, archivable, n (%)**               |      37 (100%)       |            31 (100%)            |     6 (100%)     |
| Unknown                                     |         131          |               118               |        13        |

## Trials for intervention outcome measures

Summary results reporting: 150

Publication link in registration: 55

Green OA publication: 34

## EUCTR and other cross-registrations

The IntoValue, and hence TrackValue, sample includes trials any
interventional study in the registry and is not limited to those
regulated by German drug and medical laws. Trials regulated by those
rules *should* be registered in EUCTR, rather than ClinicalTrials.gov or
DRKS. As such, trials in our sample which are cross-registered in EUCTR
are perhaps more likely clinical trials per German law (and may be more
likely to fulfil transparency requirements - note: todo).

We found that 26 (15%) trials in our sample include one or more EUCTR
ids in their registration, and are presumably cross-registered in EUCTR.
This includes 23 (15%) trials from ClinicalTrials.gov and 3 (16%) trials
from DRKS.

Considering TRNs both in the registry as well as in the publication, we
find additional potential cross-registrations in EUCTR as well as in
other registries (N = 40).

| crossreg_registry  | n_crossreg |
|:-------------------|-----------:|
| EudraCT            |         38 |
| ClinicalTrials.gov |         17 |
| DRKS               |          1 |
| ISRCTN             |          1 |

After manual checks of potential cross-registrations, we found 29 trials
with valid cross-registrations in EUCTR.

## Communication Materials

Invitations and reminders are generated and stored in
`communication-materials` with the below directory structure. Note that
`materials` and `signature-letter.pdf` are stored locally.

The communication materials are organized by timepoint and consist of:

-   0 (study launch): personalized letter (pdf) and personalized email
    (html), with different templates for trialists with one vs. multiple
    trials
-   1: generic email (html) from cvk
-   2: personalized (name only) email (html)
-   3: personalized (name only) email (html)
-   4: personalized (name only) email (html), for the intervention only

<!-- -->

    ├── materials
    │   ├── 0_email
    │   ├── 0_letter
    │   ├── 1_email
    │   │   └── cvk.html
    │   ├── 2_email
    │   ├── 3_email
    │   └── 4_email
    ├── render-communication-materials.R
    └── templates
        ├── 0_email_multi.Rmd
        ├── 0_email_one.Rmd
        ├── 0_letter_multi.Rmd
        ├── 0_letter_one.Rmd
        ├── 1_email.Rmd
        ├── 2_email.Rmd
        ├── 3_email.Rmd
        ├── 4_email.Rmd
        ├── body-multi.Rmd
        ├── body-one.Rmd
        ├── quest-letterfoot.pdf
        ├── quest-letterhead.pdf
        ├── signature-email.Rmd
        └── signature-letter.pdf
