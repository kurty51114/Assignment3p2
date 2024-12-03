## Introduction

This repository contains the necessary files and instructions to set up two Arch Linux servers with a load balancer. Each server will run a Bash script that generates a static index.html file containing system information. The script is configured to run automatically every day at 05:00 using a systemd service and timer. The generated HTML document will be served with an nginx web server running on both droplets, secured with `ufw`. A load balancer will distribute traffic between the two servers to ensure high availability and scalability. [1]

## Prerequisites

Before proceeding, ensure the following prerequisites are met:

1. Two Arch Linux DigitalOcean droplets with the tag web are set up.

2. A load balancer is configured to connect with the web tag.

3. Both servers have been updated and restarted:

```bash
sudo pacman -Syu --noconfirm
sudo reboot
```

4. The following files have been uploaded to both servers:

    a. serverSetup.sh

    b. generate_index

    c. generate_index.service

    d. generate_index.timer

## Setup Instructions

Run the serverSetup.sh script on each server to complete the setup process.

## Accessing the Web Servers

To access the web servers, navigate to the load balancer's IP address in a web browser. The load balancer will distribute traffic between the two servers. Optionally, you can access the individual servers by navigating to their respective IP addresses.

## References

[1] McNinch, Nathan. https://learn.bcit.ca/content/enforced/1063362-45842.202430/assignment3p1.pdf

[2] Nginx Arch Wiki page. https://wiki.archlinux.org/title/Nginx

[3] Nginx beginner's guide. https://nginx.org/en/docs/beginners_guide.html

[4] Arch Documentation on ufw. https://wiki.archlinux.org/title/Uncomplicated_Firewall