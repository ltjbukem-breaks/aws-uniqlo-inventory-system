# Root module - orchestrates all other modules

# Networking module
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# TODO: Call the storage module (Phase 2)
# module "storage" {
#   source = "./modules/storage"
#   ...
# }

# TODO: Call the compute module (Phase 4)
# module "compute" {
#   source = "./modules/compute"
#   ...
# }

# TODO: Call the messaging module (Phase 5)
# module "messaging" {
#   source = "./modules/messaging"
#   ...
# }

# TODO: Call the scheduling module (Phase 6)
# module "scheduling" {
#   source = "./modules/scheduling"
#   ...
# }
