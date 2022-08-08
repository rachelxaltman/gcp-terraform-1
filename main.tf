provider "google" {
  project = var.project
  region  = var.region
}

resource "google_compute_firewall" "firewall" {
  name    = "gritfy-firewall-externalssh"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["22"]
 }
  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["externalssh"]
}

resource "google_compute_firewall" "webserverrule" {
  name    = "gritfy-webserver"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["80","443"]
  }
  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["webserver"]
}

resource "google_compute_address" "static" {
  name = "vm-public-address"
  project = var.project
  region = var.region
  depends_on = [ google_compute_firewall.firewall ]
}

resource "google_compute_instance" "minecraft3" {
  name         = "minecraft3" # name of the server
  machine_type = "e2-medium" # machine type refer google machine types
  zone         = "${var.region}-b" 
  tags         = ["externalssh","webserver"] 

  boot_disk { 
    initialize_params {
      image = "debian-11-bullseye-v20220719"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }

 provisioner "remote-exec" {
   connection {
     host        = google_compute_address.static.address
    # host = "10.128.0.5"
     type        = "ssh"
     # username of the instance would vary for each account refer the OS Login in GCP documentation
     user        = var.user 
     timeout     = "500s"
     # private_key being used to connect to the VM. ( the public key was copied earlier using metadata )
     private_key = file(var.privatekeypath)
   }
   # Commands to be executed as the instance gets ready.
   # set execution permission and start the script
   inline = [
     "sudo mkdir /home/minecraft >> /var/log/minecraft.txt",
     "sudo apt-get update && sudo apt-get install wget openjdk-17-jre-headless default-jre >> /var/log/minecraft.txt",
     "sudo wget -O /home/minecraft/server.jar https://piston-data.mojang.com/v1/objects/8399e1211e95faa421c1507b322dbeae86d604df/server.jar >> /var/log/minecraft.txt",
     "sudo java  -Xms512M -jar /home/minecraft/server.jar nogui >> /var/log/minecraft.txt",
     "sudo sed -i -e 's/false/true/g' /home/minecraft/eula.txt >> /var/log/minecraft.txt",
     "sudo java  -Xms512M -jar /home/minecraft/server.jar nogui >> /var/log/minecraft.txt"
   ]
 }

depends_on = [ google_compute_firewall.firewall, google_compute_firewall.webserverrule ]
  service_account {
    email  = var.email
    scopes = ["compute-ro"]
  }
#  metadata = {
#    ssh-keys = "${var.user}:${file(var.publickeypath)}"
#  }
}





















