#!/usr/bin/env python3

import json
import sys
import os

def generate_html_from_json(json_data):
    data = json.loads(json_data)

    # HTML template
    html_template = f'''
    <html lang="en" class=""><head>
      <meta charset="UTF-8">
      <title>Cluster Info</title>
      <script src="https://cdn.tailwindcss.com"></script>
    <body>

    <div class="bg-gray-100">
      <div class="mx-auto max-w-7xl py-12 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-4xl">
          <div class="overflow-hidden bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900">Cluster Detail</h3>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">Expanded details on cluster</p>
            </div>
            <div class="border-t border-gray-200">
              <dl>
                <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt class="text-sm font-medium text-gray-500">Cluster ID</dt>
                  <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">{data['Cluster ID']}</dd>
                </div>
                <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt class="text-sm font-medium text-gray-500">Managers</dt>
                  <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                    {''.join([f"<div class='break-inside-avoid-column'>{key}</div>" for key in data['Managers']])}
                  </dd>
                </div>
                <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6"></div>
                <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt class="text-sm font-medium text-gray-500">Operating System</dt>
                  <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">{data['Operating System']}</dd>
                </div>
                <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt class="text-sm font-medium text-gray-500">Kernel Versions</dt>
                  <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                    <table class="table-auto">
                      {''.join([f"<tr><td class='pr-4'>{key}</td><td class='pr-4'>{value}</td></tr>" for key, value in data['Kernel Versions'].items()])}
                    </table>
                  </dd>
                </div>
                <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                  <dt class="text-sm font-medium text-gray-500">License Info</dt>
                  <dd class="mt-1 text-sm text-gray-900 sm:col-span-2 sm:mt-0">
                    <table class="table-auto">
                      <tr><td class="pr-8">Max Engines:</td><td>{data['License Info']['Max Engines']}</td></tr>
                      <tr><td class="pr-8">Expiration:</td><td>{data['License Info']['Expiration']}</td></tr>
                      <tr><td class="pr-8">Tier:</td><td>{data['License Info']['Tier']}</td></tr>
                      <tr><td class="pr-8">License Type:</td><td>{data['License Info']['License Type']}</td></tr>
                      <tr><td class="pr-8">Scanning Enabled:</td><td>{data['License Info']['Scanning Enabled']}</td></tr>
                    </table>
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <script src="https://cdn.tailwindcss.com"></script>
    </body></html>
    '''

    return html_template

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

    # Generate HTML from JSON
    html_output = generate_html_from_json(json_data)

    # Output the HTML to the console
    print(html_output)

    # Optionally, you can also write the HTML to a file (e.g., output.html)
    # with open("output.html", "w") as html_file:
    #     html_file.write(html_output)

if __name__ == "__main__":
    main()
