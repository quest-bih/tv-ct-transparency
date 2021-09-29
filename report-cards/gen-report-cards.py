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


def get_publication_title(row):
    pub_title = (row['pub_title'])
    if not isinstance(pub_title, str):
        if np.isnan(pub_title):
            pub_title = "title not found (doi: " + row['doi'] + ")"
    pub_title = pub_title.title()
    cutoff = 50
    if len(pub_title) > cutoff:
        pub_title = pub_title[0:cutoff] + "…"
    return pub_title


def get_registry_name(row):
    registry = row['registry']
    if not isinstance(registry, str):
        if np.isnan(registry):
            registry = "no registry information available"
    return registry


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
            False: {"layer": "summary_results_layer_1",
                    "registry": {
                        "id": "summary_results_1_registry",
                        "text": get_registry_name
                    }},
            True: {
                "is_summary_results_1y": {
                    True: {"layer": "summary_results_layer_2",
                           "link": {
                               "id": "summary_results_2_link",
                               "url": gen_registry_url,
                               "text": id_for_publication
                           },
                           "registry": {
                               "id": "summary_results_2_registry",
                               "text": get_registry_name
                           }},
                    False: {"layer": "summary_results_layer_3",
                            "link": {
                                "id": "summary_results_3_link",
                                "url": gen_registry_url,
                                "text": id_for_publication
                            },
                            "registry": {
                                "id": "summary_results_3_registry",
                                "text": get_registry_name,
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
                               "text": get_publication_title
                           }},
                    False: {"layer": "publication_layer_3",
                            "link": {
                                "id": "publication_3_link",
                                "url": url_for_publication,
                                "text": get_publication_title
                            }}
                }
            }
        }
    },
    "#linkage_full_text": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_iv_trn_ft": {
                    True: {"layer": "linkage_layer_1"},
                    False: {"layer": "linkage_layer_2"}}
            }
        }
    },
    "#linkage_abstract": {
        "has_publication": {
            False: {"layer": "linkage_layer_na"},
            True: {
                "has_iv_trn_abstract": {
                    True: {"layer": "linkage_layer_3"},
                    False: {"layer": "linkage_layer_4"}
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
                    False: {"layer": "linkage_layer_6"}
                }
            }
        }
    },
    "#registration": {
        "is_prospective": {
            True: {"layer": "registration_layer_1"},
            False: {"layer": "registration_layer_2"}
        }
    # },
    # "#action": {
    #     "has_summary_results": {
    #         True: {
    #             "has_reg_pub_link": {
    #                 True: {
    #                     "is_oa": {
    #                         True: {"layer": "action_layer_1"},
    #                         False: {
    #                             "is_closed_archivable": {
    #                                 True: {"layer": "action_layer_6"},
    #                                 False: {"layer": "action_layer_1"},
    #                                 np.NaN: {"layer": "action_layer_1"}
    #                             }
    #                         }
    #                     }
    #                 },
    #                 False: {
    #                     "is_oa": {
    #                         True: {"layer": "action_layer_7"},
    #                         False: {
    #                             "is_closed_archivable": {
    #                                 True: {"layer": "action_layer_3"},
    #                                 False: {"layer": "action_layer_7"},
    #                                 np.NaN: {"layer": "action_layer_7"}
    #                             }
    #                         }
    #                     }
    #                 }
    #             }
    #         },
    #         False: {
    #             "has_reg_pub_link": {
    #                 True: {
    #                     "is_oa": {
    #                         True: {"layer": "action_layer_8"},
    #                         False: {
    #                             "is_closed_archivable": {
    #                                 True: {"layer": "action_layer_4"},
    #                                 False: {"layer": "action_layer_8"},
    #                                 np.NaN: {"layer": "action_layer_8"}
    #                             }
    #                         }
    #                     }
    #                 },
    #                 False: {
    #                     "is_oa": {
    #                         True: {"layer": "action_layer_5"},
    #                         False: {
    #                             "is_closed_archivable": {
    #                                 True: {"layer": "action_layer_2"},
    #                                 False: {"layer": "action_layer_5"},
    #                                 np.NaN: {"layer": "action_layer_5"}
    #                             }
    #                         }
    #                     }
    #                 }
    #             }
    #         }
    #     }
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
              {'name': 'summary_results', 'number': 3, 'na': False},
              {'name': 'publication', 'number': 3, 'na': False},
              {'name': 'linkage', 'number': 6, 'na': True},
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

        # Add trial registration number
        replace(root, "text", "TRN", row['id'], gen_registry_url(row))
        # Add title of trial
        title = row['title']
        cutoff = 60
        if len(title) > cutoff:
            title = title[0:cutoff] + "…"
        replace(root, "text", "title", title, gen_registry_url(row))

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
            registry = element.get("registry")
            if registry:
                the_id = registry["id"]
                text = registry["text"](row)
                replace(root, "text", the_id, text)

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
