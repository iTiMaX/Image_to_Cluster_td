packer {
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "nginx" {
  image  = "nginx:latest"
  commit = true
  changes = [
    "EXPOSE 80",
    "CMD [\"nginx\", \"-g\", \"daemon off;\"]"
  ]
}

build {
  name = "learn-packer"
  sources = [
    "source.docker.nginx"
  ]

  # copie de index.html dans l'image
  provisioner "file" {
    source      = "index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  # application du tag sur l'image
  post-processor "docker-tag" {
    repository = "nginx-image-td"
    tag        = ["v1"]
  }
}
