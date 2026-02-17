terraform {
  source = "../../../../modules/osm-beach-extractor"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "s3_fundamental" {
  config_path = "../s3-fundamental"
}

inputs = {
  s3_bucket_name = dependency.s3_fundamental.outputs.bucket_name
  s3_bucket_arn  = dependency.s3_fundamental.outputs.bucket_arn
}
