
# Auth
gsutil auth "$json_cred_key"

# OR url param
dest="gs://my-bucket?key=$json_cred_key"

# Copy 
gsutil cp "$local_file_name" "$dest"
