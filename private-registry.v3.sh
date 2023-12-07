
#!/bin/bash

# Prompt the user for the registry FQDN
read -p "Enter registry FQDN (default: stark1.shared): " REGISTRY_FQDN
REGISTRY_FQDN=${REGISTRY_FQDN:-"stark1.shared"}

# Prompt the user for registry username
read -p "Enter registry username: " REGISTRY_USERNAME

# Prompt the user for registry password (silently)
read -s -p "Enter registry password: " REGISTRY_PASSWORD
echo  # Move to the next line after password input

rm -rf /var/lib/registry

# Create a directory to store the registry data
REGISTRY_DIR=/var/lib/registry
sudo mkdir -p $REGISTRY_DIR

# Generate a self-signed SSL certificate for the registry
# sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout $REGISTRY_DIR/domain.key -x509 -days 365 -out $REGISTRY_DIR/domain.crt -subj "/C=US/ST=YourState/L=YourCity/O=YourOrganization/OU=YourUnit/CN=$REGISTRY_FQDN"

sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout $REGISTRY_DIR/domain.key -x509 -days 365 -out $REGISTRY_DIR/domain.crt -subj "/C=US/ST=YourState/L=YourCity/O=YourOrganization/OU=YourUnit/CN=$REGISTRY_FQDN" -addext "subjectAltName = DNS:$REGISTRY_FQDN"

# docker run --rm --entrypoint htpasswd registry:2 -Bbn $REGISTRY_USERNAME $REGISTRY_PASSWORD > $REGISTRY_DIR/htpasswd
docker run --rm --entrypoint htpasswd httpd:2 -Bbn $REGISTRY_USERNAME $REGISTRY_PASSWORD >  $REGISTRY_DIR/htpasswd

# Start the Docker registry container with htpasswd
docker run -d -p 5000:5000 --restart=always --name registry \
  -v $REGISTRY_DIR:/var/lib/registry \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/var/lib/registry/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/var/lib/registry/domain.key \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/var/lib/registry/htpasswd" \
  registry:2

# Create an authentication file for the registry using htpasswd in the container
# docker exec -it registry htpasswd -Bbn $REGISTRY_USERNAME $REGISTRY_PASSWORD > $REGISTRY_DIR/htpasswd
# Restart the Docker registry container to apply authentication
# docker restart registry

# Output information
echo; echo; echo
echo "Docker registry is now running with authentication and TLS."
echo "Registry URL: https://$REGISTRY_FQDN:5000"
echo "Username: $REGISTRY_USERNAME"
echo "Password: $REGISTRY_PASSWORD"
echo

echo -e "\nDocker client configuration required. Ensure Docker is restarted for the changes to take effect."
echo "=============================================================================="

# Option 1: Disable SSL Verification
echo -e "\nOption 1: Disable SSL Verification"
echo "Create file daemon.json with the following content:"
echo "/etc/docker/daemon.json"
echo '{
    "insecure-registries": ["'$REGISTRY_FQDN:5000'"]
}'
echo "=============================================================================="

# Option 2: Trust the Self-Signed Certificate
echo -e "\nOption 2: Trust the Self-Signed Certificate"
echo "Copy domain.crt and update CA certificates:"
echo "sudo scp $REGISTRY_DIR/domain.crt user@your_node_ip:/tmp/domain.crt"
echo "sudo ssh user@your_node_ip \"sudo mv /tmp/domain.crt /usr/local/share/ca-certificates/; sudo update-ca-certificates\""
echo "=============================================================================="

# Restart Docker
echo -e "\nRestart Docker"
echo "Part 3: Restart Docker"
echo "sudo systemctl restart docker"


# Option 3: Integrate with k3s Deployed Kubernetes

echo -e "\nOption 3: Integrate with k3s Deployed Kubernetes"
echo "Copy domain.crt to k3s TLS directory:"
echo "sudo mv /tmp/domain.crt /var/lib/rancher/k3s/server/tls/"

# Restart k3s service
echo "Restart k3s service:"
echo "sudo systemctl restart k3s"

# Create r registry secret for authorization
echo "Create  registry secret for authorization:"
echo "kubectl create secret docker-registry myregistrykey \\"
echo "  --docker-server=$REGISTRY_FQDN:5000 \\"
echo "  --docker-username=$REGISTRY_USERNAME \\"
echo "  --docker-password=$REGISTRY_PASSWORD"

# Define the secret in a pod YAML
echo -e "\nDefine the secret in a pod YAML (example):"
echo "apiVersion: v1"
echo "kind: Pod"
echo "metadata:"
echo "  name: mypod"
echo "spec:"
echo "  containers:"
echo "  - name: my-container"
echo "    image: $REGISTRY_FQDN:5000/myimage:latest"
echo "  imagePullSecrets:"
echo "  - name: myregistrykey"
echo "=============================================================================="





# Echo Conclusion
echo "=============================================================================="
echo "Configuration completed. Ensure Docker is restarted for changes to take effect."
