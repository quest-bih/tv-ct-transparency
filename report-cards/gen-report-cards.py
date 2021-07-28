#!/usr/bin/python3
import argparse
import copy
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
def replace(root, section_type, id_name, text, target=None):
    results = root.xpath(f"//svg:{section_type}[@id = '{id_name}']", namespaces={"svg": "http://www.w3.org/2000/svg"})
    if not results:
        raise Exception(f"{id_name} field does not exist")

    if section_type == "g":
        node = results[0].getchildren()[0]
    else:
        node = results[0]

    node.text = text

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


def id_for_publication(row):
    return row["id"]


def doi_for_publication(row):
    doi = row['doi']
    if not isinstance(doi, str):
        if np.isnan(doi):
            doi = "no DOI available"
    return doi


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
                            True: {"layer": "open_access_layer_3"},
                            False: {"layer": "open_access_layer_4"},
                            np.NaN: {"layer": "open_access_layer_5"}
                        }
                    }
                }
            }
        },
    },
    "#summary_results": {
        "has_summary_results": {
            False: {"layer": "summary_results_layer_1"},
            True: {
                "is_summary_results_1y": {
                    True: {"layer": "summary_results_layer_2",
                           "link": {
                               "id": "summary_results_2_link",
                               "url": gen_registry_url,
                               "text": id_for_publication
                           }},
                    False: {"layer": "summary_results_layer_3",
                            "link": {
                                "id": "summary_results_3_link",
                                "url": gen_registry_url,
                                "text": id_for_publication
                            }},
                    np.NaN: {"layer": "summary_results_layer_4",
                             "link": {
                                 "id": "summary_results_4_link",
                                 "url": gen_registry_url,
                                 "text": id_for_publication
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
                    True: {"layer": "publication_layer_2",
                           "link": {
                               "id": "publication_2_link",
                               "url": url_for_publication,
                               "text": doi_for_publication
                           }},
                    False: {"layer": "publication_layer_3",
                            "link": {
                                "id": "publication_3_link",
                                "url": url_for_publication,
                                "text": doi_for_publication
                            }},
                    np.NaN: {"layer": "publication_layer_4",
                             "link": {
                                 "id": "publication_4_link",
                                 "url": url_for_publication,
                                 "text": doi_for_publication
                             }}
                }
            }
        }
    },
    "#linkage_full_text": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_iv_trn_ft_pdf": {
                    np.NaN: {"layer": "linkage_layer_1"},
                    True: {"layer": "linkage_layer_2"},
                    False: {"layer": "linkage_layer_3"}}
            }
        }
    },
    "#linkage_abstract": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_iv_trn_abstract": {
                    np.NaN: {"layer": "linkage_layer_4"},
                    True: {"layer": "linkage_layer_5"},
                    False: {"layer": "linkage_layer_6"}
                }
            }
        }
    },
    "#linkage_registry": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_reg_pub_link": {
                    np.NaN: {"layer": "linkage_layer_7"},
                    True: {"layer": "linkage_layer_8"},
                    False: {"layer": "linkage_layer_9"}
                }
            }
        }
    },
    "#registration": {
        "is_prospective": {
            True: {"layer": "registration_layer_1"},
            False: {"layer": "registration_layer_2"}
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

    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    infile = args.template

    with open(infile, "rb") as f:
        data = f.read()

    # Define XML template
    template = etree.fromstring(data)

    # Define layer characteristics in each module
    layers = [{'name': 'registration', 'number': 2, 'na': False},
              {'name': 'summary_results', 'number': 4, 'na': False},
              {'name': 'publication', 'number': 4, 'na': False},
              {'name': 'linkage', 'number': 9, 'na': True},
              {'name': 'open_access', 'number': 5, 'na': True}]

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

        # Add correct TRN
        replace(root, "text", "TRN", row['id'], gen_registry_url(row))

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

            layer = element["layer"]
            included_layers.add(layer)
            link = element.get("link")
            if link:
                url = link["url"](row)
                the_id = link["id"]
                text = link["text"](row)
                replace(root, "text", the_id, text, url)

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

# If no summary results found -> summary_results_layer_1
#if not row['has_summary_results']:
#    included_layers.add("summary_results_layer_1")
# If summary results AND timely -> summary_results_layer_2 and add link in summary_results_2_link
#elif row['has_summary_results'] and row['is_summary_results_1y'] is True:
#    included_layers.add("summary_results_layer_2")
#    replace(root, "text", "summary_results_2_link", row['id'], gen_registry_url(row))
# If summary results but NOT timely -> summary_results_layer_3 and add link in summary_results_3_link
#elif row['has_summary_results'] and not row['is_summary_results_1y']:
#    included_layers.add("summary_results_layer_3")
#    replace(root, "text", "summary_results_3_link", row['id'], gen_registry_url(row))
# If summary results but NO DATA on timeliness -> summary_results_layer_4 and add link in summary_results_4_link
#elif row['has_summary_results'] and np.isnan(row['is_summary_results_1y']):
#    included_layers.add("summary_results_layer_4")
#    replace(root, "text", "summary_results_4_link", row['id'], gen_registry_url(row))

# If no publication found -> publication_layer_1
#if not row['has_publication']:
#    included_layers.add("publication_layer_1")
# If publication found AND timely -> publication_layer_2 and add link in publication_2_link
#elif row['has_publication'] and row['is_publication_2y'] is True:
#    included_layers.add("publication_layer_2")
#    replace(root, "text", "publication_2_link", row['id'], row['url'])
# If publication found but NOT timely -> publication_layer_3 and add link in publication_3_link
#elif row['has_publication'] and not row['is_publication_2y']:
#    included_layers.add("publication_layer_3")
#    replace(root, "text", "publication_3_link", row['id'], row['url'])
# If publication found but NO DATA on timeliness -> publication_layer_3 and add link in publication_3_link
#elif row['has_publication'] and np.isnan(row['is_publication_2y']):
#    included_layers.add("publication_layer_3")
#    replace(root, "text", "publication_3_link", row['id'], row['url'])

# if TRN box not applicable as pub NOT FOUND -> linkage_layer_na
#if not row['has_publication']:
#    included_layers.add("linkage_layer_na")
# if NO DATA for TRN in full text
#elif np.isnan(row['has_iv_trn_ft_pdf']):
#    included_layers.add("linkage_layer_1")
# if TRN in full text
#elif row['has_iv_trn_ft_pdf'] is True:
#    included_layers.add("linkage_layer_2")
# if TRN NOT in full text
#elif not row['has_iv_trn_ft_pdf']:
#    included_layers.add("linkage_layer_3")

#if not row['has_publication']:
#    included_layers.add("linkage_layer_na")
# if NO DATA for TRN in abstract
#elif np.isnan(row['has_iv_trn_abstract']):
#    included_layers.add("linkage_layer_4")
# if TRN in abstract
#elif row['has_iv_trn_abstract'] is True:
#    included_layers.add("linkage_layer_5")
# if TRN NOT in abstract
#elif not row['has_iv_trn_abstract']:
#    included_layers.add("linkage_layer_6")

#if not row['has_publication']:
#    included_layers.add("linkage_layer_na")
# if NO DATA for pub linked in reg
#elif np.isnan(row['has_reg_pub_link']):
#    included_layers.add("linkage_layer_7")
# if pub linked in reg
#elif row['has_reg_pub_link'] is True:
#    included_layers.add("linkage_layer_8")
# if pub NOT linked in reg
#elif not row['has_reg_pub_link']:
#    included_layers.add("linkage_layer_9")

# If not applicable as pub NOT FOUND -> open_access_layer_na
#if not row['has_publication']:
#    included_layers.add("open_access_layer_na")
# If pub is open access -> open_access_layer_1
#elif row['is_oa'] is True:
#    included_layers.add("open_access_layer_1")
# If NO DATA on open access status -> open_access_layer_2
#elif np.isnan(row['is_oa']):
#    included_layers.add("open_access_layer_2")
# If pub is NOT open access AND CAN be made accessible -> open_access_layer_3
#elif not row['is_oa'] and row['is_closed_archivable'] is True:
#    included_layers.add("open_access_layer_3")
# If pub is NOT open access AND CANNOT be made accessible -> open_access_layer_4
#elif not row['is_oa'] and not row['is_closed_archivable']:
#    included_layers.add("open_access_layer_4")
# If pub is NOT open access AND NO permissions data -> open_access_layer_5
#elif not row['is_oa'] and np.isnan(row['is_closed_archivable']):
#    included_layers.add("open_access_layer_5")