variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "table_name" {
  description = "Name of the table. The service reads it from DYNAMODB_TABLE, which its ConfigMap (k8s/01-config/app-configmap.yaml) sets to this same default, so change it only together with the service."
  type        = string
  default     = "execution-orders"
}
