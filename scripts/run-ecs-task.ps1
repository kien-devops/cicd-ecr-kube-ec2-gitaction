param(
    [Parameter(Mandatory = $true)]
    [string]$Cluster,

    [Parameter(Mandatory = $true)]
    [string]$TaskDefinition,

    [Parameter(Mandatory = $true)]
    [string[]]$SubnetIds,

    [Parameter(Mandatory = $true)]
    [string[]]$SecurityGroupIds,

    [string]$Region = "ap-southeast-1",
    [string]$LaunchType = "FARGATE",
    [int]$Count = 1,
    [ValidateSet("ENABLED", "DISABLED")]
    [string]$AssignPublicIp = "ENABLED"
)

$ErrorActionPreference = "Stop"

$subnets = ($SubnetIds | ForEach-Object { '"{0}"' -f $_ }) -join ","
$securityGroups = ($SecurityGroupIds | ForEach-Object { '"{0}"' -f $_ }) -join ","
$networkConfiguration = "awsvpcConfiguration={subnets=[$subnets],securityGroups=[$securityGroups],assignPublicIp=$AssignPublicIp}"

Write-Host "Running ECS task..."
aws ecs run-task `
    --cluster $Cluster `
    --task-definition $TaskDefinition `
    --launch-type $LaunchType `
    --count $Count `
    --network-configuration $networkConfiguration `
    --region $Region
