import os
import sys
import json
from packaging import version
from zipfile import ZIP_DEFLATED, ZipFile
from shutil import copyfile, rmtree
from pathlib import Path

method_to_index_map = {
    "none" : -1,
    "major" : 0,
    "minor" : 1,
    "patch": 2,
    "increment": 3,
}

publish_modes = [ "zip", "no_zip" ]

package_json_location = "src/package.json"

if len(sys.argv) != 5:
    print("Invalid command line argument count!\nMust be 4 (configuration, increment method, publish mode, publish destination)")
    exit(-1)

if not sys.argv[2].lower() in method_to_index_map.keys():
    print(f"Invalid command line argument {sys.argv[2].lower()}\nMust be one of the following values!: {method_to_index_map.keys()}")
    exit(-1)
    
if not sys.argv[3].lower() in publish_modes:
    print(f"Invalid command line argument '{sys.argv[3].lower()}'\nMust be one of the following values!: {publish_modes}")

# increment the package version

incr_method = sys.argv[2].lower()
publish_method = sys.argv[3].lower()

package = None
extension_name = None

with open(package_json_location, 'r+') as package_data:
    # retrieve package version from the json file
    
    package = json.load(package_data)
    
    extension_name = package["name"]
    
    package_version = list(version.parse(package["version"]).release)
    
    # increment package version based on command line arguments
    
    if incr_method != "none":
        package_version[method_to_index_map[incr_method]] += 1
        
        for i in range(method_to_index_map[incr_method] + 1, len(package_version)):
            package_version[i] = 0
    
    # write the new version back to the json file
    
    
    old_version = package["version"]
    package["version"] = str(version.Version('.'.join([str(n) for n in package_version])))
    
    print()
    print(f"Bump version from {old_version} to {package['version']}")
    
    with open(package_json_location, 'w') as package_out:
        json.dump(package, package_out, indent=4)

# add all package files to a .asesprite-extension zip file

# lua files will all be stored at the root of the zip file, but is structured differently in the folder structure,
# so we need to grab all the needed source code files here, and later write them in a flat folder structure into the zip file.
source_files = [ package_json_location ] 

for root, _, files in os.walk("src"):
    
    folders = root.split(os.path.sep)[1:] # ignore 'src' folder
    
    # ignore specific folders depending on configuration.
    if len(folders) > 0 and not sys.argv[1] in folders:
        continue
    
    for file in files:
    
        if not file.endswith('.lua'):
            continue
    
        source_files.append(os.path.join(root, file))
    
# we actually want to keep the folder structure of asset files, so these are stored in a separate list
asset_files = [ ]

for root, _, files in os.walk('assets'):
    for file in files:
        asset_files.append(os.path.join(root, file))

publish_location = sys.argv[4]

if os.path.isfile(publish_location + extension_name):
    os.remove(publish_location + extension_name)

if not os.path.exists(publish_location):
    os.makedirs(publish_location, exist_ok=True)

destination_path = os.path.join(publish_location, extension_name)

if publish_method == "zip":

    destination_path += ".aseprite-extension"
    
    with ZipFile(destination_path, 'w', ZIP_DEFLATED) as extension_zip:
        
        # separate adding asset and source files, as the source files need to be stored in a flat file structure, in contrast to the asset files.
        
        for file in source_files:
            print(f"Adding {file} to extension")
            
            extension_zip.write(file, os.path.basename(file), compresslevel=5)
        
        for file in asset_files:
            print(f"Adding {file} to extension")
            
            # the asset files will be one level above the current directory, so we need to remove the ../ prefix,
            # inorder for them to show up in the zip file
            extension_zip.write(file, file, compresslevel=5)

elif publish_method == "no_zip":
    
    rmtree(destination_path, ignore_errors=True)
    
    for file in source_files:
        print(f"Adding {file} to extension")
        
        destination_file = os.path.join(destination_path, os.path.basename(file))
        
        Path(destination_file).parent.mkdir(parents=True, exist_ok=True)
        
        copyfile(file, destination_file)
        
    for file in asset_files:
        print(f"Adding {file} to extension")
        
        destination_file = os.path.join(destination_path, file)

        Path(destination_file).parent.mkdir(parents=True, exist_ok=True)
        
        copyfile(file, destination_file)

print()
print(f"Published extension at '{destination_path}'!")
