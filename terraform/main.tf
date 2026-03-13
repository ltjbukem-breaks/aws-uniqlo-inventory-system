# Root module - orchestrates all other modules

# Networking module
module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# Storage module
module "storage" {
  source = "./modules/storage"

  # Pass variables from root
  project_name = var.project_name
  environment  = var.environment

  # Pass outputs from networking module
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  rds_security_group_id = module.networking.rds_security_group_id
}

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
