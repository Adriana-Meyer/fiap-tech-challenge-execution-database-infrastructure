# One item per service order, with its tasks nested inside (see the service's
# ExecutionOrderItem). Only the key is declared here: DynamoDB is schemaless
# for every other attribute, so the service owns the shape of the item
# (status, tasks, saga id, and the `version` attribute that makes each write an
# optimistic lock).
#
# The key must match what the service's mapper expects (partition key
# `serviceOrderId`, a string), or every read and write would fail.
resource "aws_dynamodb_table" "execution_orders" {
  name = var.table_name

  # On-demand: no capacity to size and nothing billed while the table is idle,
  # which suits a workshop's small and uneven traffic and a Lab that is mostly off.
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "serviceOrderId"

  attribute {
    name = "serviceOrderId"
    type = "S"
  }

  # Left off so `terraform destroy` can remove the table at the end of a Lab
  # session; the data is demonstration data.
  deletion_protection_enabled = false

  tags = {
    Name = var.table_name
  }
}
