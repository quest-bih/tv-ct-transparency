#!/usr/bin/python3

import copy
import subprocess
import sys
from lxml import etree
import pandas as pd


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


def main():
    infile = sys.argv[1]

    with open(infile, "rb") as f:
        data = f.read()

    # Define XML template
    template = etree.fromstring(data)

    # Define layer characteristics in each module
    layers = [{'name': 'registration', 'number': 2, 'na': False},
              {'name': 'summary_results', 'number': 3, 'na': False},
              {'name': 'publication', 'number': 3, 'na': False},
              {'name': 'linkage', 'number': 8, 'na': True},
              {'name': 'open_access', 'number': 3, 'na': True}]

    # Build a set of all layers
    all_layers = get_all_layers(layers)

    # Read in the data with trial-specific characteristics TODO: change this to TV dataset and use whole dataset!
    data = pd.read_csv("ct-dashboard-intovalue.csv")[:5]

    # Iterate over each trial and select template to be used for each module
    for _, row in data.iterrows():
        # Use base XML content on each run
        root = copy.deepcopy(template)
        included_layers = set()
        name = row['id']
        outfile = f"{name}.svg"

        # Add correct TRN
        replace(root, "text", "TRN", row['id'], gen_registry_url(row))
        # If prospectively registered -> registration_layer_1
        if row['is_prospective']:
            included_layers.add("registration_layer_1")
        # If retrospectively registered -> registration_layer_2
        else:
            included_layers.add("registration_layer_2")
        # If summary results AND timely -> summary_results_layer_1 and add link in summary_results_1_link
        if row['has_summary_results'] and row['is_summary_results_1y']:
            included_layers.add("summary_results_layer_1")
            replace(root, "text", "summary_results_1_link", row['id'], gen_registry_url(row))
        # If summary results but NOT timely -> summary_results_layer_2 and add link in summary_results_1_link
        elif row['has_summary_results'] and not row['is_summary_results_1y']:
            included_layers.add("summary_results_layer_2")
            replace(root, "text", "summary_results_2_link", row['id'], gen_registry_url(row))
        # If no summary results found -> summary_results_layer_3
        elif not row['has_summary_results']:
            included_layers.add("summary_results_layer_3")
        # If publication found AND timely -> publication_layer_1 and add link in publication_1_link
        if row['has_publication'] and row['is_publication_2y']:
            included_layers.add("publication_layer_1")
            replace(root, "text", "publication_1_link", row['doi'], row['url'])
        # If publication found but NOT timely -> publication_layer_2 and add link in publication_1_link
        elif row['has_publication'] and not row['is_publication_2y']:
            included_layers.add("publication_layer_2")
            replace(root, "text", "publication_2_link", row['doi'], row['url'])
        # If no publication found -> publication_layer_3
        elif not row['has_publication']:
            included_layers.add("publication_layer_3")
        # If TRN in full text AND TRN in abstract AND pub linked in reg -> linkage_layer_1
        if row['has_iv_trn_ft_pdf'] and row['has_iv_trn_abstract'] and row['has_reg_pub_link']:
            included_layers.add("linkage_layer_1")
        # If TRN NOT in full text AND TRN NOT in abstract AND pub NOT linked in reg -> linkage_layer_2
        if not row['has_iv_trn_ft_pdf'] and not row['has_iv_trn_abstract'] and not row['has_reg_pub_link']:
            included_layers.add("linkage_layer_2")
        # If TRN in full text but TRN NOT in abstract AND pub NOT linked in reg -> linkage_layer_3
        if row['has_iv_trn_ft_pdf'] and not row['has_iv_trn_abstract'] and not row['has_reg_pub_link']:
            included_layers.add("linkage_layer_3")
        # If TRN NOT in full text but TRN in abstract AND pub NOT linked in reg -> linkage_layer_4
        if not row['has_iv_trn_ft_pdf'] and row['has_iv_trn_abstract'] and not row['has_reg_pub_link']:
            included_layers.add("linkage_layer_4")
        # If TRN NOT in full text AND TRN NOT in abstract but pub linked in reg -> linkage_layer_5
        if not row['has_iv_trn_ft_pdf'] and not row['has_iv_trn_abstract'] and row['has_reg_pub_link']:
            included_layers.add("linkage_layer_5")
        # If TRN in full text AND TRN in abstract BUT pub NOT linked in reg -> linkage_layer_6
        if row['has_iv_trn_ft_pdf'] and row['has_iv_trn_abstract'] and not row['has_reg_pub_link']:
            included_layers.add("linkage_layer_6")
        # If TRN in full text BUT NOT in abstract AND pub linked in reg -> linkage_layer_7
        if row['has_iv_trn_ft_pdf'] and not row['has_iv_trn_abstract'] and row['has_reg_pub_link']:
            included_layers.add("linkage_layer_7")
        # If TRN NOT in full text BUT in abstract AND pub linked in reg -> linkage_layer_8
        if not row['has_iv_trn_ft_pdf'] and row['has_iv_trn_abstract'] and row['has_reg_pub_link']:
            included_layers.add("linkage_layer_8")
        # If not applicable as pub not found -> linkage_layer_na
        if not row['has_publication']:
            included_layers.add("linkage_layer_na")
        # If pub is open access -> open_access_layer_1
        if row['is_oa']:
            included_layers.add("open_access_layer_1")
        # If pub is NOT open access AND CAN be made accessible -> open_access_layer_2
        if not row['is_oa'] and row['is_archivable']:
            included_layers.add("open_access_layer_2")
        # If pub is NOT open access AND CAN NOT be made accessible -> open_access_layer_3
        if not row['is_oa'] and not row['is_archivable']:
            included_layers.add("open_access_layer_3")
        # If not applicable as pub not found -> open_access_layer_na
        if not row['has_publication']:
            included_layers.add("open_access_layer_na")

        # Define which layers need to be excluded for this trial
        layers_to_exclude = all_layers - included_layers

        remove_layers(root, layers_to_exclude)

        # objectify.deannotate(root)
        # etree.cleanup_namespaces(root)
        out = etree.tostring(root, pretty_print=True, encoding="utf-8")

        with open(outfile, "wb") as f:
            f.write(out)

        outpdf = f"{name}.pdf"

        # Convert modified SVG to PDF with inkscape (open source)
        subprocess.run([
            "/Applications/Inkscape.app/Contents/MacOS/inkscape",
            f"--export-filename={outpdf}",
            outfile,
        ], check=True)


if __name__ == "__main__":
    main()