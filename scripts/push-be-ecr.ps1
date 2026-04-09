param(
    [Parameter(Mandatory = $true)]
    [string]$AwsAccountId,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,

    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$dockerContext = Join-Path $repoRoot "hopital_BE\Hospital_API"
$dockerfilePath = Join-Path $dockerContext "Dockerfile"
$repositoryUri = "$AwsAccountId.dkr.ecr.$Region.amazonaws.com/$RepositoryName"
$imageUri = "${repositoryUri}:$ImageTag"
$localImage = "hospital-be:$ImageTag"

Write-Host "Checking ECR repository $RepositoryName in $Region..."

$null = aws ecr describe-repositories `
    --repository-names $RepositoryName `
    --region $Region 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Repository not found. Creating it..."
    aws ecr create-repository `
        --repository-name $RepositoryName `
        --region $Region | Out-Null
}

Write-Host "Logging in to ECR..."
aws ecr get-login-password --region $Region `
| docker login --username AWS --password-stdin "$AwsAccountId.dkr.ecr.$Region.amazonaws.com"

Write-Host "Building backend image from $dockerContext..."
docker build `
    -f $dockerfilePath `
    -t $localImage `
    $dockerContext

Write-Host "Tagging image as $imageUri..."
docker tag $localImage $imageUri

Write-Host "Pushing image to ECR..."
docker push $imageUri

Write-Host ""
Write-Host "Done. Backend image pushed:"
Write-Host $imageUri
