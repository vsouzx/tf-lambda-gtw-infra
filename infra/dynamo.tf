resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = var.dynamo_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "funcional"
  range_key      = "cod_ciclo"

  attribute {
    name = "funcional"
    type = "S"
  }

  attribute {
    name = "cod_ciclo"
    type = "N"
  }

  tags = {
    Name        = "dynamodb-table-1"
    Environment = var.stage_name
  }
}