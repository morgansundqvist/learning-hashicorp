variable "gcp_region" {
  description = "The GCP region to deploy resources into."
  type        = string
  default     = "europe-north1" # <-- Set your desired default region here
}

variable "gcp_zone" {
  description = "The GCP zone within the region."
  type        = string
  default     = "europe-north1-a" # <-- Set your desired default zone here
}

variable "gcp_project_id" {
  description = "The GCP project ID to deploy into."
  type        = string
  default     = "" # <-- Set your default project ID here
}
