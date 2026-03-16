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

# Messaging module
module "messaging" {
  source = "./modules/messaging"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
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
  sales_processor_dlq_arn       = module.messaging.sales_processor_dlq_arn
  product_updater_dlq_arn       = module.messaging.product_updater_dlq_arn
  inventory_restock_dlq_arn     = module.messaging.inventory_restock_dlq_arn
}

# Scheduling module
module "scheduling" {
  source = "./modules/scheduling"

  project_name                    = var.project_name
  environment                     = var.environment
  inventory_restock_lambda_arn    = module.compute.inventory_restock_arn
  inventory_restock_function_name = module.compute.inventory_restock_function_name
}
