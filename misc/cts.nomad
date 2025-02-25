job "consul-terraform-sync" {
  datacenters = ["byb"]
  type        = "service"
  group "cts" {
    count = 1
    network {
      mode = "bridge"
      port "cts" {}
    }
    volume "consul-api" {
      type   = "host"
      source = "consul-api"
    }
    task "agent" {
      driver = "docker"
      config {
        image = "hashicorp/consul-terraform-sync:0.6.0"
        args = [
          "consul-terraform-sync",
          "start",
          "-config-file=${NOMAD_SECRETS_DIR}/cts.hcl"
        ]
        mounts = [{
          type     = "bind"
          source   = "secrets/terraformrc"
          target   = "/home/consul-terraform-sync/.terraformrc"
          readonly = true
        }]
      }
      resources {
        cpu    = 500 # 500 MHz
        memory = 256 # 256MB
      }
      volume_mount {
        volume      = "consul-api"
        destination = "${NOMAD_SECRETS_DIR}/consul"
      }
      vault {
        policies    = ["consul-terraform-sync"]
        change_mode = "restart"
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/terraformrc"
        data = <<-EOT
          credentials "app.terraform.io" {
            token = "{{ with secret "kv/terraform-cloud" }}{{ .Data.data.token }}{{ end }}"
          }
        EOT
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/cts.env"
        env         = true
        data        = <<-EOT
          {{ with secret "kv/unifi" }}
          UNIFI_INSECURE=true
          UNIFI_API="https://unifi.byb.lan"
          UNIFI_USERNAME="{{ .Data.data.username }}"
          UNIFI_PASSWORD="{{ .Data.data.password }}"
          {{ end }}
        EOT
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/cts.hcl"
        data        = <<-EOT
          log_level = "DEBUG"
          port = {{ env "NOMAD_PORT_cts" }}
          consul {
            address = "unix://{{ env "NOMAD_SECRETS_DIR" }}/consul/consul.sock"
            token   = "{{ with secret "consul/creds/consul-terraform-sync" }}{{ .Data.token }}{{ end }}"
          }
          task {
            name        = "unifi-port-forward"
            description = "Pushes port-forwarding rules to Unifi Network"
            enabled     = true
            providers   = ["unifi"]
            module      = "app.terraform.io/krarey/port-forwarding/unifi"
            condition "services" {
              regexp = ".*"
              filter = "Service.Meta contains \"unifi-proto\" and Service.Meta contains \"unifi-port-forward\""
            }
          }
          driver "terraform" {
            log         = false
            persist_log = false

            backend "consul" {
              gzip = true
            }

            required_providers {
              unifi = {
                source  = "paultyng/unifi"
                version = "~> 0.34.1"
              }
            }
          }
        EOT
      }
    }
  }
}
