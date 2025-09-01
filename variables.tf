variable "upload_s3_files" {
  description = "Whether to upload files to S3 (set to false after initial upload)"
  type        = bool
  default     = true
}

variable "debug" {
  description = "Enable debug mode"
  type        = bool
  default     = false
}

variable "enable_file_prep" {
  description = "Enable file preparation module for pre-infrastructure file setup"
  type        = bool
  default     = true
}