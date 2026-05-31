variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "instance_count" {
  type        = number
  description = "Number of H100 (a3-highgpu-8g) BK agent VMs to create"
}

variable "machine_type" {
  type        = string
  default     = "a3-highgpu-8g"
  description = "GCE machine type (a3-highgpu-8g = 8x H100 80GB SXM5)"
}

variable "accelerator_type" {
  type        = string
  default     = "nvidia-h100-80gb"
  description = "Accelerator type — nvidia-h100-80gb for a3-highgpu, nvidia-h100-mega-80gb for a3-megagpu"
}

variable "accelerator_count" {
  type        = number
  default     = 8
  description = "Number of GPUs per VM (8 for *-8g machine types)"
}

variable "disk_size" {
  type        = number
  default     = 500
  description = "Size of the boot disk in GB"
}

variable "disk_type" {
  type        = string
  default     = "pd-balanced"
  description = "GCE boot disk type"
}

variable "local_ssd_count" {
  type        = number
  default     = 16
  description = "Number of local NVMe SSDs (a3-highgpu-8g requires 16)"
}

variable "buildkite_queue_name" {
  type        = string
  default     = "h100_8_queue"
  description = "Buildkite queue tag for these agents"
}

variable "buildkite_token_value" {
  type        = string
  description = "Agent token used to connect to Buildkite."
  sensitive   = true
}

variable "huggingface_token_value" {
  type        = string
  description = "Hugging Face token for vLLM model serving usage."
  sensitive   = true
}

variable "resource_suffix" {
  type        = string
  default     = ""
  description = "Suffix to append to resource names to avoid collisions across zones"
}
