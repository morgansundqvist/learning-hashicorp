terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.33" # Use a recent version
    }
  }
}

provider "google" {
  project = var.gcp_project_id # <-- Use the variable
  region  = var.gcp_region     # <-- Use the variable
  zone    = var.gcp_zone       # <-- Use the variable
}

# ------------------------------------------------------------------------------
# Networking Setup
# ------------------------------------------------------------------------------

resource "google_compute_network" "main_vpc" {
  name                            = "main-vpc"
  auto_create_subnetworks         = false # We'll create a custom subnet
  mtu                             = 1460  # Standard MTU
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "main_subnet" {
  name          = "main-subnet"
  ip_cidr_range = "10.10.1.0/24" # Private IP range for your instances
  region        = var.gcp_region
  network       = google_compute_network.main_vpc.id
  # private_ip_google_access = true # Enable if instances need Google APIs without external IPs
}

# ------------------------------------------------------------------------------
# Firewall Rules
# ------------------------------------------------------------------------------

resource "google_compute_firewall" "allow_internal" {
  name      = "allow-internal-traffic"
  network   = google_compute_network.main_vpc.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"] # Allow all TCP ports internally
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"] # Allow all UDP ports internally
  }
  allow {
    protocol = "icmp" # Allow ping etc.
  }

  # Allow traffic only from other instances within the same subnet
  source_ranges = [google_compute_subnetwork.main_subnet.ip_cidr_range]
  # Alternative: Use tags
  # source_tags = ["internal-allowed"]
  # target_tags = ["internal-allowed"]
}

resource "google_compute_firewall" "allow_ssh" {
  name      = "allow-ssh-ingress"
  network   = google_compute_network.main_vpc.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"] # Allow SSH port
  }

  # --- IMPORTANT SECURITY NOTE ---
  # Using "0.0.0.0/0" allows SSH from ANY IP address and is NOT recommended for production.
  # For production:
  # 1. Use GCP IAP Tunneling (recommended): source_ranges = ["35.235.240.0/20"]
  # 2. Restrict to your specific office/VPN IP ranges: source_ranges = ["YOUR_OFFICE_IP/32"]
  # 3. Use a Bastion Host setup.
  # For this example, we use 0.0.0.0/0 with this warning.
  source_ranges = ["35.235.240.0/20"] # <-- !! CHANGE FOR PRODUCTION !!

  # Apply this rule only to instances with the "ssh-allowed" tag
  target_tags = ["ssh-allowed"]
}

# ------------------------------------------------------------------------------
# Compute Instances Setup (3 Instances)
# ------------------------------------------------------------------------------

resource "google_compute_instance" "app_instance" {
  count        = 3                             # Create 3 identical instances
  name         = "app-instance-${count.index}" # Names: app-instance-0, app-instance-1, app-instance-2
  machine_type = "f1-micro"                    # Example machine type
  zone         = var.gcp_zone                  # Place instances in the configured zone

  tags = ["ssh-allowed", "internal-allowed"] # Apply tags for firewall rules

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2504-amd64" # Example Ubuntu LTS image
      size  = 10                                  # GB
      type  = "pd-standard"                       # Standard persistent disk
    }
  }

  # Define the network interface to connect to our custom VPC/subnet
  network_interface {
    subnetwork = google_compute_subnetwork.main_subnet.id
    # By omitting 'access_config {}', these instances will ONLY have private IPs.
    # This is generally more secure. Access them via SSH through IAP, a bastion host,
    # or from another machine within the VPC.
  }

  # Service account - using the default Compute Engine service account
  # You might want to create a dedicated service account with specific permissions
  service_account {
    scopes = [                                          # Scopes define API access for the instance
      "https://www.googleapis.com/auth/cloud-platform", # Broad access, refine if needed
    ]
  }

  # --- SSH Key ---
  # Add your PUBLIC SSH key here to allow access.
  # Replace 'YOUR_USERNAME' and the key content.
  # You can generate a key pair using `ssh-keygen`.
  metadata = {
    ssh-keys = "" # <-- REPLACE THIS
  }

  # Ensures network resources are created before instances
  depends_on = [
    google_compute_subnetwork.main_subnet,
    google_compute_firewall.allow_internal,
    google_compute_firewall.allow_ssh,
  ]
}

# ------------------------------------------------------------------------------
# Outputs (Optional)
# ------------------------------------------------------------------------------

output "instance_private_ips" {
  description = "Private IP addresses of the created instances."
  value       = google_compute_instance.app_instance[*].network_interface[0].network_ip
}

output "instance_names" {
  description = "Names of the created instances."
  value       = google_compute_instance.app_instance[*].name
}
