# Gets article-level self-archiving permission for publications
# by querying ShareYourPaper's permissions API (https://openaccessbutton.org/api)
# Focuses on the best permission

import pandas as pd
import requests
import requests_cache
from ratelimit import limits, sleep_and_retry
import json
import time
import configparser
import datetime
import os
import re


# Define file name
filename = "2021-06-16_trackvalue-oa"
shortname = re.sub("\d{4}\-(0?[1-9]|1[012])\-(0?[1-9]|[12][0-9]|3[01])*","", filename)

# Load paths from the config file
cfg = configparser.ConfigParser()
cfg.read("config.ini")

# Get date to add to output file names
today = datetime.datetime.today()
datestamp = today.strftime("%Y-%m-%d")

# Define data folder
data_folder = cfg["paths"]["processed_data"]

# Define path to file with the data
data_file = os.path.join(data_folder, filename + ".csv")

# Read input dataset containing DOIs and OA status
data = pd.read_csv(data_file)

# Filter for closed publications
closed = data[(data['color'] == 'closed')]
print("Number of closed publications: ", closed.shape[0])

# Base URL
url = "https://api.openaccessbutton.org/permissions/"

dois = set(closed['doi'].values.tolist())

requests_cache.install_cache('permissions_cache')


# Set the rate limit to 1 call per 2 seconds
@sleep_and_retry
@limits(calls=1, period=2)
def call_api_server(url, doi):
    now = time.ctime(int(time.time()))
    response = requests.get(url + doi)
    print("Time: {0} / Used Cache: {1}".format(now, response.from_cache))

    if response.status_code != 200:
        raise Exception('API response: {}'.format(response.status_code))
    return response.json()


def call_api(url, doi):
    req = requests.Request('GET', url + doi)

    cache = requests_cache.get_cache()

    prepped = requests.Session().prepare_request(req)
    cache_key = cache.create_key(prepped)

    try:
        response = cache.get_response(cache_key)
    except (ImportError, TypeError):
        response = None

    if response:
        return response.json()

    return call_api_server(url, doi)


def get_parameters(output_formatted):

    # Skip DOIs which have no best_permission key or a null best_permission
    if not output_formatted.get("best_permission"):
        return None

    best_permission = output_formatted["best_permission"]

    # Can you self-archive the manuscript in any way?
    can_archive = best_permission.get("can_archive")

    # Where can the version named be archived?
    archiving_locations = best_permission.get("locations")

    if not archiving_locations:
        inst_repository = None
    else:
        inst_repository = 'institutional repository' in archiving_locations

    # What versions can be archived?
    versions = best_permission.get("versions")

    if not versions:
        submitted_version = None
        accepted_version = None
        published_version = None
    else:
        submitted_version = 'submittedVersion' in versions
        accepted_version = 'acceptedVersion' in versions
        published_version = 'publishedVersion' in versions

    # License required to be applied to the article
    licenses_required = best_permission.get("licences")

    # What institution is issuing the best permission?
    permission_issuer = best_permission["issuer"].get("type")

    # What is the embargo?
    embargo = best_permission.get("embargo_months")

    if not embargo:
        date_elapsed_embargo = None
        embargo_na_or_elapsed = None
    else:
        # Compare the calculated elapsed date to query date
        if embargo == 0:
            date_elapsed_embargo = None
            embargo_na_or_elapsed = True
        else:
            date_elapsed_embargo = best_permission.get("embargo_end")
            embargo_na_or_elapsed = datetime.datetime.strptime(date_elapsed_embargo, '%Y-%m-%d') < today

    # Define a final permission that depends on several conditions being met
    permission_accepted = can_archive and accepted_version and embargo_na_or_elapsed and inst_repository
    permission_published = can_archive and published_version and embargo_na_or_elapsed and inst_repository

    return can_archive, archiving_locations, inst_repository, versions, submitted_version, accepted_version, \
           published_version, licenses_required, permission_issuer, embargo, date_elapsed_embargo, \
           embargo_na_or_elapsed, permission_accepted, permission_published


def jprint(obj):
    # create a formatted string of the Python JSON object
    text = json.dumps(obj, sort_keys=True, indent=4)
    print(text)


unresolved_dois = []
no_best_perm_dois = []
result = []

# make the API request
for doi in dois:
    print(doi)
    try:
        output = call_api(url, doi)
    except Exception as e:
        print("Exception raised with DOI:", doi, e)
        unresolved_dois.append(doi)
        continue

    tmp = get_parameters(output)
    if not tmp:
        print(f"SKIPPED: {doi}")
        no_best_perm_dois.append(doi)
        continue

    result.append((doi, ) + tmp)

# Create a dataframe to store the results
df = pd.DataFrame(result, columns=['doi', 'can_archive', 'archiving_locations', 'inst_repository', 'versions',
                                   'submitted_version', 'accepted_version', 'published_version', 'licenses_required',
                                   'permission_issuer', 'embargo', 'date_elapsed_embargo', 'embargo_na_or_elapsed',
                                   'permission_accepted', 'permission_published'])

merged_result = data.merge(df, on='doi', how='left')
merged_result.to_csv(os.path.join(data_folder, datestamp + shortname + "-permissions.csv"), index=False)

unresolved = pd.DataFrame(unresolved_dois, columns=['doi'])
no_best_perm = pd.DataFrame(no_best_perm_dois, columns=['doi'])

unresolved.to_csv(os.path.join(data_folder, datestamp + shortname + "-unresolved-permissions.csv"), index=False)
no_best_perm.to_csv(os.path.join(data_folder, datestamp + shortname + "-no-best-permissions.csv"), index=False)

print("Number of unresolved DOIs: ", len(unresolved_dois))
print("Number of DOIs without a best permission: ", len(no_best_perm_dois))
