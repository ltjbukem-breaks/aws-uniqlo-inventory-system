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

# Compute module
module "compute" {
  source = "./modules/compute"

  project_name             = var.project_name
  environment              = var.environment
  private_subnet_ids       = module.networking.private_subnet_ids
  lambda_security_group_id = module.networking.lambda_security_group_id
  db_secret_arn            = module.storage.db_secret_arn
  sales_data_bucket_name        = module.storage.sales_data_bucket_name
  product_updates_bucket_name   = module.storage.product_updates_bucket_name
  sales_data_bucket_arn         = module.storage.sales_data_bucket_arn
  product_updates_bucket_arn    = module.storage.product_updates_bucket_arn
}

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
