# enteraTerraform
Terraform document that creates a docker host behind an ELB and deploys an nginx container with custom content loaded in via a locally built dockerfile. Also serves the associated enteraDocker repo and its associated containers and services.

This repository contains a terraform doc that instantiates a ubuntu docker host and an ELB configured to stand in front of it.  The terraform doc requires the input of the target vpc_id, the users aws ID, the users aws aws key, an ssh public key, and an IP address from which the "terraform apply" is to be run. This document creates an ELB instead of an ALB because there is only a single site with a single page being served up, with no need for the load balancer to perform any actions on the application layer.
