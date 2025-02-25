job "valheim" {
  datacenters = ["x86"]

  group "valheim" {
    network {
      mode = "bridge"
      port "game1" {
        to = 2456
      }
      port "game2" {
        to = 2457
      }
    }

    service {
      name = "valheim"
      port = "game1"
      tags = ["game1"]
      # Port-forward hinting for Consul-Terraform Sync
      meta {
        unifi-port-forward = "2456"
        unifi-proto        = "udp"
      }
    }

    service {
      name = "valheim"
      port = "game2"
      tags = ["game2"]
      meta {
        unifi-port-forward = "2457"
        unifi-proto        = "udp"
      }
    }

    volume "valheim_data" {
      type   = "host"
      source = "valheim_data"
    }

    volume "valheim_config" {
      type   = "host"
      source = "valheim_config"
    }

    task "valheim-server" {
      driver = "docker"
      env {
        SERVER_NAME   = "Valheimestry"
        WORLD_NAME    = "valheimestry"
        SERVER_PUBLIC = "false"
        RESTART_CRON  = "0 10 * * *"
        UPDATE_CRON   = "0 */3 * * *"
        PUID          = 1024
        PGID          = 1024
      }
      config {
        image = "ghcr.io/lloesche/valheim-server"
      }
      resources {
        cpu    = 6000
        memory = 4096
      }
      template {
        data        = <<-EOT
          SERVER_PASS="{{ with secret "kv/valheim" }}{{ .Data.data.server_password }}{{ end }}"
        EOT
        destination = "${NOMAD_SECRETS_DIR}/valheim.env"
        env         = true
      }
      vault {
        policies = ["valheim"]
      }
      volume_mount {
        volume      = "valheim_data"
        destination = "/opt/valheim"
      }
      volume_mount {
        volume      = "valheim_config"
        destination = "/config"
      }
    }
  }
}
