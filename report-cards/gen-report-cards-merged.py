#!/usr/bin/python3
import argparse
import copy
import fnmatch
import os
import subprocess
import sys
from lxml import etree
import pandas as pd
import numpy as np


# Function to add hyperlinks
def linkify(node, target):
    link = etree.Element("a")
    link.attrib["{http://www.w3.org/1999/xlink}href"] = target
    link.attrib["target"] = "_blank"

    parent = node.getparent()
    # Insert hyperlink anchors at the right level (where node comes from)
    parent.insert(parent.index(node), link)
    parent.remove(node)

    # Insert content of link
    link.insert(0, node)


# Function to replace text
def replace(root, section_type, id_name, text=None, target=None):
    results = root.xpath(f"//svg:{section_type}[@id = '{id_name}']", namespaces={"svg": "http://www.w3.org/2000/svg"})
    if not results:
        print(f"WARNING: {id_name} field does not exist")
        return
        #raise Exception(f"{id_name} field does not exist")

    if section_type == "g":
        node = results[0].getchildren()[0]
    else:
        node = results[0]

    if text is not None:
        node.text = str(text)

    if not target:
        return

    linkify(node, target)


# Function to select and delete layers
def remove_layers(root, layers_to_exclude):
    for layer_to_exclude in layers_to_exclude:
        layer = root.xpath(f"//svg:g[@id = '{layer_to_exclude}']", namespaces={"svg": "http://www.w3.org/2000/svg"})

        if not layer:
            raise Exception(f"{layer_to_exclude} field does not exist")

        node = layer[0]

        parent = node.getparent()
        parent.remove(node)


# Function to build layer names in a specific module (e.g., registration)
def gen_layer(desc):
    result = []
    name = desc["name"]
    number = desc["number"]
    for i in range(number):
        result.append(f"{name}_layer_{i+1}")
    if desc["na"]:
        result.append(f"{name}_layer_na")
    return set(result)


# Function to combine all layers across all modules
def get_all_layers(layers):
    all_layers = set()
    for layer in layers:
        all_layers.update(gen_layer(layer))
    return all_layers


# Function to build the link to the registry (CT.gov or DRKS)
def gen_registry_url(row):
    registry = row['registry']
    if registry == "ClinicalTrials.gov":
        url = "https://clinicaltrials.gov/ct2/show/" + row['id']
    elif registry == "DRKS":
        url = "https://www.drks.de/drks_web/navigate.do?navigationId=trial.HTML&TRIAL_ID=" + row['id']
    else:
        raise RuntimeError(f"Unknown registry {registry}")
    return url


def url_for_publication(row):
    url = row["url"]

    if not isinstance(url, str):
        if np.isnan(url):
            url = ""
    return url


def url_for_improve_sumres(row):
    registry = row['registry']
    if registry == "ClinicalTrials.gov":
        url = "https://clinicaltrials.gov/ct2/manage-recs/how-report"
    elif registry == "DRKS":
        url = "https://www.drks.de/drks_web/navigate.do?navigationId=edit&messageDE=Studien%20registrieren&messageEN=Register%20trials"
    else:
        raise RuntimeError(f"Unknown registry {registry}")
    return url


def url_for_improve_link(row):
    registry = row['registry']
    if registry == "ClinicalTrials.gov":
        url = "https://prsinfo.clinicaltrials.gov/tutorial/content/index.html#/lessons/GE_igGejMjFu9WtErAxXw9-qdeUggVBX"
    elif registry == "DRKS":
        url = "https://www.drks.de/drks_web/navigate.do?navigationId=edit&messageDE=Studien%20registrieren&messageEN=Register%20trials"
    else:
        raise RuntimeError(f"Unknown registry {registry}")
    return url


def url_for_library(row):
    url = "https://bibliothek.charite.de/en/publishing/open_access/the_green_route_to_open_access/"
    return url


def url_for_euctr_crossreg(row):
    # TODO: change to EUCTR TRN!
    url = "https://www.clinicaltrialsregister.eu/ctr-search/search?query=" + row['id']

    if not isinstance(url, str):
        if np.isnan(url):
            url = ""
    return url


def id_for_publication(row):
    return row["id"]


def get_publication_title(row):
    pub_title = (row['pub_title'])
    if not isinstance(pub_title, str):
        if np.isnan(pub_title):
            pub_title = "DOI: " + row['doi']
    else:
        pub_title = pub_title.title()
    cutoff = 45
    if len(pub_title) > cutoff:
        pub_title = pub_title[0:cutoff] + "…"
    return pub_title


def get_registry_name(row):
    registry = row['registry']
    if not isinstance(registry, str):
        if np.isnan(registry):
            registry = "N/A"
    return registry


def get_days_reg_to_start(row):
    days_reg_to_start = abs(row['days_reg_to_start'])
    if not isinstance(days_reg_to_start, str):
        if np.isnan(days_reg_to_start):
            days_reg_to_start = "N/A"
    return days_reg_to_start


def get_start_date(row):
    start_date = row['start_date']
    if not isinstance(start_date, str):
        if np.isnan(start_date):
            start_date = "N/A"
    return start_date


def get_completion_date(row):
    completion_date = row['completion_date']
    if not isinstance(completion_date, str):
        if np.isnan(completion_date):
            completion_date = "N/A"
    return completion_date


def get_euctr_trn(row):
    #TODO: change to EUCTR TRN!
    return row["id"]


def get_trn(row):
    return "'" + row["id"] + "'"


def gen_core_facility_email(row):
    email = "mailto:studienergebnisse@charite.de"
    return email


TABLE = {
    "#open_access": {
        "has_publication": {
            False: {"layer": "open_access_layer_na"},
            True: {
                "is_oa": {
                    True: {"layer": "open_access_layer_1"},
                    np.NaN: {"layer": "open_access_layer_2"},
                    False: {
                        "is_closed_archivable": {
                            True: {"layer": "open_access_layer_3",
                                   "link_syp": {
                                       "id": "open_access_improve_3a_syp",
                                       "url": "https://shareyourpaper.org"
                                   },
                                   "link_library": {
                                       "id": "open_access_improve_3a_library",
                                       "url": url_for_library
                                   }},
                            False: {"layer": "open_access_layer_4"},
                            np.NaN: {"layer": "open_access_layer_4"}
                        }
                    }
                }
            }
        },
    },
    "#summary_results": {
        "has_summary_results": {
            False: {"layer": "summary_results_layer_1",
                    "registry": {
                        "id": "summary_results_registry_1a",
                        "text": get_registry_name
                    },
                    "improve_registry": {
                        "id": "summary_results_improve_registry_1a",
                        "text": get_registry_name
                    },
                    "improve_sumres_link": {
                        "id": "summary_results_improve_link_1a",
                        "url": url_for_improve_sumres
                    }},
            True: {
                "is_summary_results_1y": {
                    False: {"layer": "summary_results_layer_2",
                           "registry": {
                               "id": "summary_results_registry_2a",
                               "text": get_registry_name
                           },
                           "completion_date": {
                               "id": "summary_results_completion_2b",
                               "text": get_completion_date
                           }},
                    True: {"layer": "summary_results_layer_3",
                            "registry": {
                                "id": "summary_results_registry_3a",
                                "text": get_registry_name,
                            },
                            "completion_date": {
                                "id": "summary_results_completion_3b",
                                "text": get_completion_date
                            }}
                }

            }
        }
    },
    "#publication": {
        "has_publication": {
            False: {"layer": "publication_layer_1"},
            True: {
                "is_publication_2y": {
                    False: {"layer": "publication_layer_2",
                           "link": {
                               "id": "publication_link_2a",
                               "url": url_for_publication,
                               "text": get_publication_title
                           },
                           "completion_date": {
                               "id": "publication_completion_date_2b",
                               "text": get_completion_date
                           }},
                    True: {"layer": "publication_layer_3",
                            "link": {
                                "id": "publication_link_3a",
                                "url": url_for_publication,
                                "text": get_publication_title
                            },
                            "completion_date": {
                                "id": "publication_completion_date_3b",
                                "text": get_completion_date
                            }}
                }
            }
        }
    },
    "#linkage_abstract": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_iv_trn_abstract": {
                    True: {"layer": "linkage_layer_1",
                           "trn": {
                               "id": "linkage_trn_1a",
                               "text": get_trn
                           }},
                    False: {"layer": "linkage_layer_2",
                            "trn": {
                                "id": "linkage_trn_2a",
                                "text": get_trn
                            }}}
            }
        }
    },
    "#linkage_full_text": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_iv_trn_ft": {
                    True: {"layer": "linkage_layer_3",
                           "trn": {
                               "id": "linkage_trn_3b",
                               "text": get_trn
                           }},
                    False: {"layer": "linkage_layer_4",
                            "trn": {
                                "id": "linkage_trn_4b",
                                "text": get_trn
                            }}
                }
            }
        }
    },
    "#linkage_registry": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_reg_pub_link": {
                    True: {"layer": "linkage_layer_5"},
                    False: {"layer": "linkage_layer_6",
                            "registry": {
                                "id": "linkage_improve_registry",
                                "text": get_registry_name
                            },
                            "improve_linkage_link": {
                                "id": "linkage_improve_link",
                                "url": url_for_improve_link
                            }}
                }
            }
        }
    },
    "#registration": {
        "is_prospective": {
            True: {"layer": "registration_layer_1",
                   "registry": {
                       "id": "registration_registry_1",
                       "text": get_registry_name
                   },
                   "days_reg_to_start": {
                       "id": "registration_days_1",
                       "text": get_days_reg_to_start
                   },
                   "start_date": {
                       "id": "registration_start_date_1",
                       "text": get_start_date
                   }},
            False: {"layer": "registration_layer_2",
                    "registry": {
                        "id": "registration_registry_2",
                        "text": get_registry_name
                    },
                    "days_reg_to_start": {
                        "id": "registration_days_2",
                        "text": get_days_reg_to_start
                    },
                    "start_date": {
                        "id": "registration_start_date_2",
                        "text": get_start_date
                    }}
        }
    },
    "#euctr_crossreg": {
        "has_crossreg_eudract": {
            True: {
                # TODO: change to is_prospective in EudraCT
                "is_prospective": {
                    True: {
                        # TODO: change to has results posted in EudraCT
                        "has_summary_results": {
                            True: {
                                "layer": "euctr_crossreg_layer_1",
                                "euctr_trn": {
                                    "id": "euctr_crossreg_trn_1",
                                    "text": get_euctr_trn,
                                    "url": url_for_euctr_crossreg
                                }},
                            False: {
                                "layer": "euctr_crossreg_layer_2",
                                "euctr_trn": {
                                    "id": "euctr_crossreg_trn_2",
                                    "text": get_euctr_trn,
                                    "url": url_for_euctr_crossreg
                                },
                                "improve_euctr_crossreg_link": {
                                    "id": "euctr_crossreg_improve_link_2",
                                    "email": gen_core_facility_email
                                }},
                        }
                    },
                    False: {
                        "has_summary_results": {
                            True: {
                                "layer": "euctr_crossreg_layer_3",
                                "euctr_trn": {
                                    "id": "euctr_crossreg_trn_3",
                                    "text": get_euctr_trn,
                                    "url": url_for_euctr_crossreg
                                }},
                            False: {
                                "layer": "euctr_crossreg_layer_4",
                                "euctr_trn": {
                                    "id": "euctr_crossreg_trn_4",
                                    "text": get_euctr_trn,
                                    "url": url_for_euctr_crossreg
                                },
                                "improve_euctr_crossreg_link": {
                                    "id": "euctr_crossreg_improve_link_4",
                                    "email": gen_core_facility_email
                                }},
                        }
                    }
                }
            },
            False: {
                "layer": "euctr_crossreg_layer_na"
            }
        }
    }
}


def main():
    parser = argparse.ArgumentParser(description='Create report cards')
    parser.add_argument('template', metavar='TEMPLATE', type=str,
                        help='The template to use')
    parser.add_argument('data', metavar='DATA', type=str,
                        help='The data to use (.csv file)')
    parser.add_argument('--outdir', metavar='DIR', type=str,
                        default=os.getcwd(), dest="outdir",
                        help='Where to store the output (default: current work dir)')
    parser.add_argument('--filter', metavar='FILTER', type=str,
                        help='Filter trials by TRN')

    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    infile = args.template

    with open(infile, "rb") as f:
        data = f.read()

    # Define XML template
    template = etree.fromstring(data)

    # Define layer characteristics in each module
    layers = [{'name': 'registration', 'number': 2, 'na': False},
              {'name': 'summary_results', 'number': 3, 'na': False},
              {'name': 'publication', 'number': 3, 'na': False},
              {'name': 'linkage', 'number': 6, 'na': True},
              {'name': 'open_access', 'number': 4, 'na': True},
              {'name': 'euctr_crossreg', 'number': 4, 'na': True}]

    # Build a set of all layers
    all_layers = get_all_layers(layers)

    # Read in the data with trial-specific characteristics
    data = pd.read_csv(args.data)

    # Iterate over each trial and select template to be used for each module
    for _, row in data.iterrows():
        # Use base XML content on each run
        root = copy.deepcopy(template)
        included_layers = set()
        name = row['id']
        outfile = os.path.join(args.outdir, f"{name}.svg")

        if args.filter and not fnmatch.fnmatch(name, args.filter):
            continue

        # Add trial registration number
        replace(root, "g", "TRN", row['id'] + ":", gen_registry_url(row))
        # Add title of trial
        title = row['title']
        cutoff = 105
        if len(title) > cutoff:
            title = title[0:cutoff] + "…"
        replace(root, "g", "title", title)

        for key, value in TABLE.items():
            if key.startswith("#"):
                key = next(iter(value))  # get the new key
                value = value[key]       # get new value

            while key != "layer":
                condition = row[key]
                value = value[condition]  # go one level deeper
                key = next(iter(value))   # get the new key
                element = value
                value = value[key]

            for k, v in element.items():
                if k == "layer":
                    included_layers.add(v)
                    continue

                the_id = v["id"]
                text = v.get("text")
                url = v.get("url") or v.get("email")

                if text and callable(text):
                    text = text(row)
                if url and callable(url):
                    url = url(row)

                replace(root, "g", the_id, text, url)

        # Define which layers need to be excluded for this trial
        layers_to_exclude = all_layers - included_layers

        remove_layers(root, layers_to_exclude)

        # objectify.deannotate(root)
        # etree.cleanup_namespaces(root)
        out = etree.tostring(root, pretty_print=True, encoding="utf-8")

        with open(outfile, "wb") as f:
            f.write(out)

        outpdf = os.path.join(args.outdir, f"{name}.pdf")

        # Convert modified SVG to PDF with inkscape (open source)
        subprocess.run([
            "/Applications/Inkscape.app/Contents/MacOS/inkscape",
            f"--export-filename={outpdf}",
            outfile,
        ], check=True)


if __name__ == "__main__":
    main()
