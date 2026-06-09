job "store-app" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 1

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:stable"
        port_map = { http = 80 }
      }

      resources {
        cpu    = 500
        memory = 256
      }

      service {
        name = "store-app"
        port = "http"
        tags = ["edge","store"]
      }
    }

    network {
      port "http" {
        static = 31080
      }
    }
  }
}
