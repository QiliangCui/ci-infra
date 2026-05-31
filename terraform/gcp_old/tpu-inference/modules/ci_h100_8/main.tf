data "google_client_config" "gcp_client" {
  provider = google-beta
}

resource "google_compute_instance" "buildkite-agent-instance" {
  provider = google-beta
  count    = var.instance_count
  name     = "vllm-ci-h100-8${var.resource_suffix}-${count.index}"

  machine_type = var.machine_type

  boot_disk {
    auto_delete = true
    device_name = "vllm-ci-h100-8${var.resource_suffix}-${count.index}"
    initialize_params {
      image = "projects/deeplearning-platform-release/global/images/family/common-cu129-ubuntu-2404-nvidia-580"
      size  = var.disk_size
      type  = var.disk_type
    }
    mode = "READ_WRITE"
  }

  # a3-highgpu-8g requires all 16 local SSDs (NVMe).
  dynamic "scratch_disk" {
    for_each = range(var.local_ssd_count)
    content {
      interface = "NVME"
    }
  }

  guest_accelerator {
    type  = var.accelerator_type
    count = var.accelerator_count
  }

  # GPU VMs cannot live-migrate; must TERMINATE on host maintenance.
  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = true
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  network_interface {
    nic_type = "GVNIC"
    access_config {
      nat_ip = google_compute_address.static[count.index].address
    }
    subnetwork = "projects/${var.project_id}/regions/${data.google_client_config.gcp_client.region}/subnetworks/default"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  metadata = {
    enable-osconfig  = "TRUE"
    enable-oslogin   = "true"
    "install-nvidia-driver" = "False"  # DL image already has driver + CUDA + nvidia-docker
    "startup-script" = <<-EOF
      #!/bin/bash
      set -e

      # DL image has docker + nvidia-container-toolkit + nvidia driver pre-installed.
      # We add: buildkite-agent + bk CLI + minijinja-cli (matches ci_cpu_64_core).

      apt-get update
      apt-get install -y curl build-essential jq

      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      /root/.cargo/bin/cargo install minijinja-cli
      cp /root/.cargo/bin/minijinja-cli /usr/bin/minijinja-cli
      chmod 777 /usr/bin/minijinja-cli

      curl -fsSL "https://packages.buildkite.com/buildkite/cli-deb/gpgkey" | sudo gpg --dearmor -o /usr/share/keyrings/buildkite_cli-deb-archive-keyring.gpg
      echo -e "deb [signed-by=/usr/share/keyrings/buildkite_cli-deb-archive-keyring.gpg] https://packages.buildkite.com/buildkite/cli-deb/any/ any main\ndeb-src [signed-by=/usr/share/keyrings/buildkite_cli-deb-archive-keyring.gpg] https://packages.buildkite.com/buildkite/cli-deb/any/ any main" | sudo tee /etc/apt/sources.list.d/buildkite-buildkite-cli-deb.list

      curl -fsSL https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198 | sudo gpg --dearmor -o /usr/share/keyrings/buildkite-agent-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/buildkite-agent-archive-keyring.gpg] https://apt.buildkite.com/buildkite-agent stable main" | sudo tee /etc/apt/sources.list.d/buildkite-agent.list
      apt-get update
      apt-get install -y bk buildkite-agent

      sudo systemctl stop buildkite-agent

      sudo usermod -a -G docker buildkite-agent
      sudo -u buildkite-agent gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
      sudo -u buildkite-agent gcloud auth configure-docker us-docker.pkg.dev --quiet

      sudo sed -i "s/xxx/${var.buildkite_token_value}/g" /etc/buildkite-agent/buildkite-agent.cfg
      sudo sed -i 's/name="%hostname-%spawn"/name="vllm-h100-8-vm-${count.index}"/' /etc/buildkite-agent/buildkite-agent.cfg
      echo 'tags="queue=${var.buildkite_queue_name}"' | sudo tee -a /etc/buildkite-agent/buildkite-agent.cfg
      echo 'HF_TOKEN=${var.huggingface_token_value}' | sudo tee -a /etc/environment

      systemctl restart docker
      systemctl enable buildkite-agent
      systemctl start buildkite-agent
    EOF
  }
}

resource "google_compute_address" "static" {
  provider = google-beta
  count    = var.instance_count
  name     = "vllm-ci-h100-8${var.resource_suffix}-${count.index}-ip"
}
