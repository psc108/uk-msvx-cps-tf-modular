@echo off
echo Removing S3 file resources from Terraform state...

REM Get list of S3 objects and remove them
for /f "delims=" %%i in ('terraform state list ^| findstr "module.s3_files.aws_s3_object"') do (
    echo Removing: %%i
    terraform state rm "%%i"
)

REM Remove SSM resources
terraform state rm aws_ssm_document.cso_setup 2>nul
terraform state rm aws_ssm_association.cso_setup 2>nul

echo State cleanup completed. S3 files are now managed by AWS CLI.
pause