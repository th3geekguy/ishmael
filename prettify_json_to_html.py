#!/usr/bin/env python3

import json
import sys
import os

def load_html_template():
    # Get the directory of the script
    script_dir = os.path.dirname(os.path.realpath(__file__))

    # Construct the full path to the HTML template file
    html_template_path = os.path.join(script_dir, "html_template_dark.html")

    # Read HTML template from the file
    with open(html_template_path, 'r') as html_template_file:
        return html_template_file.read()

def generate_html_from_json(json_data, html_template):
    data = json.loads(json_data)

    html_output = html_template.format(
        f_cluster_id=data['Cluster ID'],
        f_managers=''.join([f"<div class='break-inside-avoid-column'>{key}</div>" for key in data['Managers']]),
        f_operating_systems=''.join([f"<tr><td class='pr-4'>{key}</td><td class='pr-4'>{value}</td></tr>" for key, value in data['Operating System'].items()]),
        f_kernel_versions=''.join([f"<tr><td class='pr-4'>{key}</td><td class='pr-4'>{value}</td></tr>" for key, value in data['Kernel Versions'].items()]),
        f_max_engines=data['License Info']['Max Engines'],
        f_expiration=data['License Info']['Expiration'],
        f_tier=data['License Info']['Tier'],
        f_license_type=data['License Info']['License Type'],
        f_scanning_enabled=data['License Info']['Scanning Enabled']
    )

    return html_output

def main():
    # Check if a JSON file is provided as a command-line argument
    if len(sys.argv) != 2:
        print("Usage: python script.py <json_file>")
        sys.exit(1)

    json_file_path = sys.argv[1]

    # Check if the JSON file exists
    if not os.path.exists(json_file_path):
        print(f"Error: JSON file '{json_file_path}' not found.")
        sys.exit(1)

    # Read JSON data from the file
    with open(json_file_path, 'r') as json_file:
        json_data = json_file.read()

    # Load HTML template from the file
    html_template = load_html_template()

    # Generate HTML from JSON
    html_output = generate_html_from_json(json_data, html_template)

    # Output the HTML to the console
    print(html_output)

    # Optionally, you can also write the HTML to a file (e.g., output.html)
    # with open("output.html", "w") as html_file:
    #     html_file.write(html_output)

if __name__ == "__main__":
    main()
